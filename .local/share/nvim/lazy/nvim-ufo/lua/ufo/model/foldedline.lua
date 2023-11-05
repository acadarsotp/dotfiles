local api = vim.api

---@class UfoFoldedLine
---@field id number
---@field bufnr number
---@field ns number
---@field text? string
---@field width? number
---@field virtText? UfoExtmarkVirtTextChunk[]
local FoldedLine = {}

function FoldedLine:new(bufnr, ns, text, width)
    local o = setmetatable({}, self)
    self.__index = self
    o.id = nil
    o.bufnr = bufnr
    o.ns = ns
    o.text = text
    o.width = width
    o.virtText = nil
    return o
end

---
---@param width number
---@return boolean
function FoldedLine:widthChanged(width)
    return self.width ~= width
end

function FoldedLine:textChanged(text)
    return self.text ~= text
end

function FoldedLine:hasVirtText()
    return self.virtText ~= nil
end

function FoldedLine:deleteVirtText()
    if self.id then
        api.nvim_buf_del_extmark(self.bufnr, self.ns, self.id)
    end
end

function FoldedLine:updateVirtText(lnum, endLnum, virtText)
    self.id = api.nvim_buf_set_extmark(self.bufnr, self.ns, lnum - 1, 0, {
        id = self.id,
        end_row = endLnum - 1,
        end_col = 0,
        virt_text = virtText,
        virt_text_win_col = 0,
        priority = 10,
        hl_mode = 'combine'
    })
    self.virtText = virtText
end

function FoldedLine:range()
    local mark = api.nvim_buf_get_extmark_by_id(self.bufnr, self.ns, self.id, {details = true})
    local row, details = mark[1], mark[3]
    local endRow = details.end_row
    return row + 1, endRow + 1
end

return FoldedLine
