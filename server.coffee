express = require 'express'
util    = require './src/util'
formats = require './src/formats'
Data    = require './lib/data/data'

{ShowerRenderer} = require './src/shower_renderer'


# Express.js Configuration
# ========================

app = express.createServer()

app.configure ->
  app.use(express.bodyParser());
  app.use(app.router)
  app.use(express.static("#{__dirname}/public", { maxAge: 41 }))


# Helpers
# =======

# Looks almost like Haskell's partial application :-)

sendHttpError = (res) -> (httpCode) -> (error) ->
  res.statusCode = httpCode
  res.end "Error: #{error.message or error}"

handleError = (errorCallback, successCallback) -> (err, args...) ->
  if err
    errorCallback err
  else
    successCallback args...


# Handlers
# ========

handleConversion = (res, url, format, getDocument) ->
  res.charset = 'utf8'
  sendError = sendHttpError res
  
  unless format
    # bad request
    return sendError(400)(new Error("Unknown target format."))
  
  console.log("Got request to convert '#{url}' to #{format.name}")
  
  getDocument url, handleError sendError(404), (doc) ->
    renderDoc(res, url, doc, format)


renderDoc = (res, url, doc, format) ->
  sendError = sendHttpError res
  util.makeDocDir url, handleError sendError(500), (docDir) ->
    
    if format.name is 'shower'
      continuation = ->
        new ShowerRenderer(doc).render (html, resources) ->
          res.header('Content-Type', format.mime)
          res.end(html)
    else
      continuation = ->
        util.convert format, doc, docDir, handleError sendError(500), (resultStream) ->
          resultStream.on 'error', sendError(500)
          console.log("Converting '#{url}' to #{format.name}.")
          if format.name is 'pdf'
            util.generatePdf resultStream, docDir, handleError sendError(500), (pdfStream) ->
              res.header('Content-Type', 'application/pdf')
              pdfStream.pipe(res)
          else
            res.header('Content-Type', format.mime)
            resultStream.pipe(res)
    
    if format.downloadResources
      util.downloadResources doc, docDir, handleError sendError(500), ->
        console.log("Downloaded resources for document '#{url}'")
        continuation()
    else
      continuation()

handleParsing = (res, format, text) ->
  sendError = sendHttpError(res)
  
  if ['markdown', 'latex'].indexOf(format) is -1
    sendError(400)(new Error "Not a supported format: #{format}")
    return
  
  stream = util.parse format, text
  stream.on 'error', sendError(500)
  res.header('Content-Type', 'application/json')
  stream.pipe(process.stdout)
  stream.pipe(res)


# Routes
# ======

app.post "/convert", (req, res) ->
  format = req.body.format
  url = "/post-data#{req.body.id}"
  handleConversion res, url, formats.byExtension[format], (_url, cb) ->
    cb(null, util.jsonToDocument(req.body))

app.get /^\/[a-zA-Z0-9_]+\.([a-z0-9]+)/, (req, res) ->
  extension = req.params[0]
  {url} = req.query
  handleConversion(res, url, formats.byExtension[extension], util.fetchDocument)

# Fallback for those who have JavaScript disabled
app.get '/render', (req, res) ->
  {url,format} = req.query
  handleConversion(res, url, formats.byExtension[format], util.fetchDocument)

app.post "/parse", (req, res) ->
  {format,text} = req.body
  handleParsing(res, format, text)


# Start the fun
# =============

# Catch errors that may crash the server
process.on 'uncaughtException', (err) ->
  console.error("Caught exception: #{err}")

app.listen(4004)
console.log("Letterpress is listening at http://localhost:4004")
