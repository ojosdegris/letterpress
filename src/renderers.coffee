# PandocRenderer
# ==============
#
# Converts a substance document to Pandoc's JSON representation.
# Pandoc is a document converter writter in Haskell that can convert between a
# plethora of formats, including LaTeX, HTML and Markdown.
# Pandoc can also serialize (and deserialize) it's internal representation of
# documents from/to JSON.
#
# * [Pandoc's internal representation](https://github.com/jgm/pandoc-types/blob/master/Text/Pandoc/Definition.hs)
# * [The rules for deriving a JSON representation of a Haskell data structure](http://hackage.haskell.org/packages/archive/json/0.4.3/doc/html/src/Text-JSON-Generic.html#toJSON)

class exports.PandocRenderer

  constructor: (@doc) ->
  
  render: ->
    # Traverse the document
    @renderPart(@doc, 0)

  renderPart: (node, args...) ->
    @[node.type._id](node, args...)

  inlineHtml: (html) -> { RawInline: ['unparsed-html',html.trim()] }

  blockHtml: (html) -> { RawBlock: ['unparsed-html',html.trim()] }

  nullAttr: -> ['', [], []]

  renderChildren: (node, level) ->
    renderedChildren = node.all('children').values().map (child) =>
      @renderPart child, level+1
    flatten = (list) -> list.reduce ((a, b) -> a.concat b), []
    flatten(renderedChildren)

  "/type/document": (node, level) ->
    renderedChildren = @renderChildren(node, level)
    
    # render abstract as a paragraph
    renderedChildren.unshift({ Para: [@inlineHtml lead] }) if lead = node.get('lead')
    
    date = node.get('published_on')
    date = Date.parse(date) if date
    
    formatDate = (d) ->
      #"#{d.getMonth()+1}/#{d.getDate()}/#{d.getFullYear()}"
      # unfortunately, Date.prototype is broken on my machine
      ""
    
    [
      {
        docTitle: [@inlineHtml(node.get('title') or "")]
        docAuthors: [[@inlineHtml(node.get('creator').get('name'))]]
        docDate: if date then [@inlineHtml formatDate(date)] else []
      }
    ,
      renderedChildren
    ]
  
  "/type/story":        (node, level) -> @["/type/document"](node, level)
  "/type/conversation": (node, level) -> @["/type/document"](node, level)
  "/type/article":      (node, level) -> @["/type/document"](node, level)
  "/type/manual":       (node, level) -> @["/type/document"](node, level)
  "/type/qaa":          (node, level) -> @["/type/document"](node, level)
  
  "/type/section": (node, level) ->
    level = Math.min(level, 6)
    
    renderedChildren = @renderChildren(node, level)
    renderedHeader = { Header: [level, [@inlineHtml node.get('name')]] }
    renderedChildren.unshift(renderedHeader)
    
    renderedChildren

  "/type/text": (node, level) ->
    [@blockHtml node.get('content').trim()]
      
  "/type/code": (node, level) ->
    [{ CodeBlock: [@nullAttr(), node.get('content') ] }]
    
  "/type/image": (node, level) ->
    # In Pandoc, images are inline elements => wrap them with a paragraph
    # caption
    [{ Para: [{ Image: [[@inlineHtml(node.get('caption'))], [node.get('url'), []]] }] }]
    
  "/type/resource": (node, level) ->
    [@blockHtml "<p>Resources are not yet implemented.</p>"]
  
  "/type/quote": (node, level) ->
    [
      { BlockQuote: [@blockHtml(node.get('content'))] }
      { Para: ['EmDash', 'Space', @inlineHtml(node.get('author'))] }
    ]
  
  "/type/question": (node, level) ->
    [@blockHtml "<p>Questions are not yet implemented.</p>"]
    
  "/type/answer": (node, level) ->
    [@blockHtml "<p>Answers are not yet implemented.</p>"]

  "/type/visualization": (node, level) ->
    [@blockHtml "<p>Visualizations are not supported.</p>"]
