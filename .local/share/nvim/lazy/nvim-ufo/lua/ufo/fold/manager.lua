local buffer     = require('ufo.model.foldbuffer')
local event      = require('ufo.lib.event')
local disposable = require('ufo.lib.disposable')
local bufmanager = require('ufo.bufmanager')
local utils      = require('ufo.utils')
local driver     = require('ufo.fold.driver')
local log        = require('ufo.lib.log')

---@class UfoFoldBufferManager
---@field initialized boolean
---@field buffers UfoFoldBuffer[]
---@field providerSelector function
---@field closeKinds UfoFoldingRangeKind[]
---@field disposables UfoDisposable[]
local FoldBufferManager = {}

---
---@param namespace number
---@param selector function
---@param closeKinds UfoFoldingRangeKind[]
---@return UfoFoldBufferManager
function FoldBufferManager:initialize(namespace, selector, closeKinds)
    if self.initialized then
        return self
    end
    self.ns = namespace
    self.providerSelector = selector
    self.closeKinds = closeKinds
    self.buffers = {}
    self.initialized = true
    self.disposables = {}
    table.insert(self.disposables, disposable:create(function()
        for _, fb in pairs(self.buffers) do
            fb:dispose()
        end
        self.buffers = {}
        self.initialized = false
    end))
    event:on('BufDetach', function(bufnr)
        local fb = self:get(bufnr)
        if fb then
            fb:dispose()
        end
        self.buffers[bufnr] = nil
    end, self.disposables)
    event:on('BufReload', function(bufnr)
        local fb = self:get(bufnr)
        if fb then
            fb:dispose()
        end
    end, self.disposables)

    local function optChanged(bufnr, new, old)
        if old ~= new then
            local fb = self:get(bufnr)
            if fb then
                fb.providers = nil
            end
        end
    end

    event:on('BufTypeChanged', optChanged, self.disposables)
    event:on('FileTypeChanged', optChanged, self.disposables)
    event:on('BufLinesChanged', function(bufnr, _, firstLine, lastLine, lastLineUpdated)
        local fb = self:get(bufnr)
        if fb then
            fb:handleFoldedLinesChanged(firstLine, lastLine, lastLineUpdated)
        end
    end, self.disposables)
    self.providerSelector = selector
    return self
end

---
---@param bufnr number
---@return boolean
function FoldBufferManager:attach(bufnr)
    local fb = self:get(bufnr)
    if not fb then
        self.buffers[bufnr] = buffer:new(bufmanager:get(bufnr), self.ns)
    end
    return not fb
end

---
---@param bufnr number
---@return UfoFoldBuffer
function FoldBufferManager:get(bufnr)
    return self.buffers[bufnr]
end

function FoldBufferManager:dispose()
    disposable.disposeAll(self.disposables)
    self.disposables = {}
end

function FoldBufferManager:parseBufferProviders(fb, selector)
    if not utils.isBufLoaded(fb.bufnr) then
        return
    end
    if not selector then
        fb.providers = {'lsp', 'indent'}
        return
    end
    local res
    local providers = selector(fb.bufnr, fb:filetype(), fb:buftype())
    local t = type(providers)
    if t == 'nil' then
        res = {'lsp', 'indent'}
    elseif t == 'string' or t == 'function' then
        res = {providers}
    elseif t == 'table' then
        res = {}
        for _, m in ipairs(providers) do
            if #res == 2 then
                error('Return value of `provider_selector` only supports {`main`, `fallback`} ' ..
                    [[combo, don't add providers more than two into return table.]])
            end
            table.insert(res, m)
        end
    else
        res = {''}
    end
    fb.providers = res
end

function FoldBufferManager:isFoldMethodsDisabled(fb)
    if not fb.providers then
        self:parseBufferProviders(fb, self.providerSelector)
    end
    return not fb.providers or fb.providers[1] == ''
end

function FoldBufferManager:getRowPairsByScanning(fb, winid)
    local rowPairs = {}
    for _, range in ipairs(fb:scanFoldedRanges(winid)) do
        local row, endRow = range[1], range[2]
        rowPairs[row] = endRow
    end
    return rowPairs
end

---
---@param bufnr number
---@param ranges? UfoFoldingRange[]
---@return boolean
function FoldBufferManager:applyFoldRanges(bufnr, ranges)
    local fb = self:get(bufnr)
    if not fb then
        return false
    end
    local winid = utils.getWinByBuf(bufnr)
    local changedtick = fb:changedtick()
    if ranges then
        local mode = utils.mode()
        if not utils.isWinValid(winid) or utils.isDiffOrMarkerFold(winid) or
            -- TODO
            -- open a buffer through terminal will get a `t` mode
            mode ~= 'n' and (mode ~= 't' or fb:buftype() == 'terminal') then
            fb.version = changedtick
            fb.foldRanges = ranges
            fb.status = 'pending'
            return false
        end
    elseif changedtick ~= fb.version or not utils.isWinValid(winid) then
        return false
    end
    local rowPairs = {}
    local isFirstApply = not fb.scanned
    if not fb.scanned then
        rowPairs = self:getRowPairsByScanning(fb, winid)
        for _, range in ipairs(ranges or fb.foldRanges) do
            if range.kind and vim.tbl_contains(self.closeKinds, range.kind) then
                local startLine, endLine = range.startLine, range.endLine
                rowPairs[startLine] = endLine
                fb:closeFold(startLine + 1, endLine + 1)
            end
        end
        fb.scanned = true
    else
        local ok, res = pcall(function()
            for _, range in ipairs(fb:getRangesFromExtmarks()) do
                local row, endRow = range[1], range[2]
                rowPairs[row] = endRow
            end
        end)
        if not ok then
            log.info(res)
            fb:resetFoldedLines(true)
            rowPairs = self:getRowPairsByScanning(fb, winid)
        end
    end
    fb.version = changedtick
    if ranges then
        fb.foldRanges = ranges
    end

    local view, wrow
    -- topline may changed after applying folds, resotre topline to save our eyes
    if isFirstApply and not vim.tbl_isempty(rowPairs) then
        view = utils.saveView(winid)
        wrow = utils.wrow(winid)
    end
    log.info('apply fold ranges:', fb.foldRanges)
    log.info('apply fold rowPairs:', rowPairs)
    driver:createFolds(winid, fb.foldRanges, rowPairs)
    if view and utils.wrow(winid) ~= wrow then
        view.topline, view.topfill = utils.evaluateTopline(winid, view.lnum, wrow)
        utils.restView(winid, view)
    end
    return true
end

return FoldBufferManager
