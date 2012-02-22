_ = require 'underscore'
EventEmitter = require 'event-emitter'
LineMap = require 'line-map'
Point = require 'point'
Range = require 'range'
Delta = require 'delta'

module.exports =
class LineWrapper
  constructor: (@maxLength, @highlighter) ->
    @buffer = @highlighter.buffer
    @buildLineMap()
    @highlighter.on 'change', (e) => @handleChange(e)

  setMaxLength: (@maxLength) ->
    oldRange = @rangeForAllScreenLines()
    @buildLineMap()
    newRange = @rangeForAllScreenLines()
    @trigger 'change', { oldRange, newRange }

  buildLineMap: ->
    @lineMap = new LineMap
    @lineMap.insertAtBufferRow 0, @buildScreenLinesForBufferRows(0, @buffer.lastRow())

  handleChange: (e) ->
    oldBufferRange = e.oldRange
    newBufferRange = e.newRange

    oldScreenRange = @lineMap.screenRangeForBufferRange(@expandRangeToLineEnds(oldBufferRange))
    newScreenLines = @buildScreenLinesForBufferRows(newBufferRange.start.row, newBufferRange.end.row)
    @lineMap.replaceBufferRows oldBufferRange.start.row, oldBufferRange.end.row, newScreenLines
    newScreenRange = @lineMap.screenRangeForBufferRange(@expandRangeToLineEnds(newBufferRange))

    @trigger 'change', { oldRange: oldScreenRange, newRange: newScreenRange }

  expandRangeToLineEnds: (bufferRange) ->
    { start, end } = bufferRange
    new Range([start.row, 0], [end.row, @lineMap.lineForBufferRow(end.row).text.length])

  rangeForAllScreenLines: ->
    endRow = @screenLineCount() - 1
    endColumn = @lineMap.lineForScreenRow(endRow).text.length
    new Range([0, 0], [endRow, endColumn])

  buildScreenLinesForBufferRows: (start, end) ->
    _(@highlighter
      .lineFragmentsForRows(start, end)
      .map((screenLine) => @wrapScreenLine(screenLine))).flatten()

  wrapScreenLine: (screenLine, startColumn=0) ->
    screenLines = []
    splitColumn = @findSplitColumn(screenLine.text)

    if splitColumn == 0 or splitColumn == screenLine.text.length
      screenLines.push screenLine
      endColumn = startColumn + screenLine.text.length
    else
      [leftHalf, rightHalf] = screenLine.splitAt(splitColumn)
      leftHalf.screenDelta = new Delta(1, 0)
      screenLines.push leftHalf
      endColumn = startColumn + leftHalf.text.length
      screenLines.push @wrapScreenLine(rightHalf, endColumn)...

    _.extend(screenLines[0], {startColumn, endColumn})
    screenLines

  findSplitColumn: (line) ->
    return line.length unless line.length > @maxLength

    if /\s/.test(line[@maxLength])
      # search forward for the start of a word past the boundary
      for column in [@maxLength..line.length]
        return column if /\S/.test(line[column])
      return line.length
    else
      # search backward for the start of the word on the boundary
      for column in [@maxLength..0]
        return column + 1 if /\s/.test(line[column])
      return @maxLength

  screenRangeForBufferRange: (bufferRange) ->
    @lineMap.screenRangeForBufferRange(bufferRange)

  screenPositionForBufferPosition: (bufferPosition, eagerWrap=true) ->
    @lineMap.screenPositionForBufferPosition(bufferPosition, eagerWrap)

  bufferPositionForScreenPosition: (screenPosition) ->
    @lineMap.bufferPositionForScreenPosition(screenPosition)

  screenLineForRow: (screenRow) ->
    @screenLinesForRows(screenRow, screenRow)[0]

  screenLinesForRows: (startRow, endRow) ->
    @lineMap.linesForScreenRows(startRow, endRow)

  screenLines: ->
    @screenLinesForRows(0, @screenLineCount() - 1)

  screenLineCount: ->
    @lineMap.screenLineCount()

_.extend(LineWrapper.prototype, EventEmitter)
