; This is for backwards-compatibility with old versions of nvim-treesitter
; The new versions have renamed this parser to "vimdoc"
(h1
  (word)+ @name @start
  (tag)
  (#set! "kind" "Interface")
) @type

(h2
  (word)+ @name @start
  (tag)
  (#set! "kind" "Interface")
) @type

(tag
  text: (word) @name
  (#set! "kind" "Interface")
) @type
