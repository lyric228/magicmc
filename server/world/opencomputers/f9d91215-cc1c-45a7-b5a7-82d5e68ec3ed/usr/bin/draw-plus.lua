local term = require("term")
local comp = require("component")
local keyboard = require("keyboard")
local sh = require("shell")
local fs = require("filesystem")
local serial = require("serialization")
local gpu = comp.gpu
local event = require("event")
term.clear()

local file = 1
white = 0xFFFFFF
black = 0x000000
path = "/"..string.sub(sh.getWorkingDirectory(), 2, #sh.getWorkingDirectory() - 1)

screen = {}

function screen:newPane(object, w, h)
    object = object or {}
    setmetatable(object, self)
    self.__index = self
    object.width = w
    object.height = h
    object.colour = black
    object.renderBool = true
    object.isMoveable = true
    object.textInputs = {}
    object.textInputCount = 0
    return object
end

function screen:resize(w, h)
    self.oldW = self.width
    self.oldH = self.height
    self.width = w
    self.height = h
    if self.boxTab ~= nil then
        for i = 1, #self.boxTab do
            if self.boxTab[i]["scaleable"] then
                self.boxTab[i]["width"] = self.width - (self.oldW - self.boxTab[i]["width"])
                if self.boxTab[i]["height"] ~= 1 then
                    if self.boxTab[i]["height"] == self.oldH then
                        self.boxTab[i]["height"] = self.height
                    elseif self.boxTab[i]["height"] == self.oldH - 3 then
                        self.boxTab[i]["height"] = self.height - 3
                    else
                        self.boxTab[i]["height"] = self.height - (self.oldH - self.boxTab[i]["height"])
                    end
                end
            end
        end
    end
    if self.textInputs ~= nil then
        for i = 1, #self.textInputs do
            if self.textInputs[i]["scaleable"] then
                self.textInputs[i]["width"] = self.width - (self.oldW - self.textInputs[i]["width"])
                if self.textInputs[i]["height"] ~= 1 then
                    if self.textInputs[i]["height"] == self.oldH then
                        self.textInputs[i]["height"] = self.height
                    elseif self.textInputs[i]["height"] == self.oldH - 3 then
                        self.textInputs[i]["height"] = self.height - 3
                    else
                        self.textInputs[i]["height"] = self.height - (self.oldH - self.textInputs[i]["height"])
                    end
                end
            end
        end
    end
    if self.buttonTab ~= nil then
        for i = 1, #self.buttonTab do
            if self.buttonTab[i]["label"] == "X" then
                self.buttonTab[i]["xPos"]  = self.width - 1
            elseif self.buttonTab[i]["label"] == "^" then
                self.buttonTab[i]["xPos"]  = self.width - 2
            elseif self.buttonTab[i]["label"] == "_" then
                self.buttonTab[i]["xPos"]  = self.width - 3
            end
        end
    end
end

function screen:move(newx, newy)
    if self.isMoveable then
        self.xPos = newx
        self.yPos = newy
    end
end

function screen:center()
    w, h = gpu.getResolution()
    xOffset = math.floor((w - self.width) / 2)
    yOffset = math.floor((h - self.height) / 2)
    self:move(xOffset, yOffset)
end

--TEXT FUNCTIONS

function screen:text(xText, yText, bgCol, tCol, newText, cent)
    if newText == nil then return end
    xText = xText - 1
    yText = yText - 1
    if self.printTab == nil then
        self.printTab = {}
        self.printCount = 0
    end
    self.printCount = self.printCount + 1
    self.printTab[self.printCount] = {
        xPos = xText,
        yPos = yText,
        bgCol = bgCol,
        tCol = tCol,
        text = newText,
        }
    if cent ~= nil then
        self.printTab[self.printCount]["centre"] = true
    else
        self.printTab[self.printCount]["centre"] = true
    end
end

function screen:centerText(xStart, yLine, xEnd, bgCol, tCol, newText)
    offset = math.floor((xEnd - #newText) / 2)
    self:text(xStart + offset, yLine, bgCol, tCol, newText, "centre")
end

--DRAW FUNCTIONS--

function screen:box(stx, sty, w, h, col, scale)
    stx = stx - 1
    sty = sty - 1
    if self.boxTab == nil then
        self.boxTab = {}
        self.boxCount = 0
    end
    self.boxCount = self.boxCount + 1
    self.boxTab[self.boxCount] = {
        xPos = stx,
        yPos = sty,
        width = w,
        height = h,
        colour = col,
        scaleable = false,
        }
    if scale ~= nil then
        self.boxTab[self.boxCount]["scaleable"] = true
    end
end

--DATA READOUT FUNCTIONS--

function screen:addTextBox(identifier, xPos, yPos, width, height, bgCol, tCol)
    if self.textBox == nil then
        self.textBox = {}
        self.textBoxCount = 0
    end
    self.textBoxCount = self.textBoxCount + 1
    self:box(xPos, yPos, width, height, bgCol, "scale")
    self.textBox[self.textBoxCount] = {
        label = identifier,
        xPos = xPos,
        yPos = yPos,
        width = width,
        height = height,
        bgCol = bgCol,
        tCol = tCol,
        selected = false,
        lineCount = 0
        }
    self.textBox[self.textBoxCount]["line"] = {}
end

function screen:printText(id, newText)
    for i = 1, #self.textBox do
        if id == self.textBox[i]["label"] then
            self.textBox[i]["lineCount"] = self.textBox[i]["lineCount"] + 1
            self.textBox[i]["line"][self.textBox[i]["lineCount"]] = newText
            self.needRender = true
            return true
        end
    end
end

--BUTTON FUNCTIONS--

function screen:button(label, stx, sty, w, h, col, returnVal)
    stx = stx - 1
    sty = sty - 1
    if self.buttonTab == nil then
        self.buttonTab = {}
        self.buttonCount = 0
    end
    self.buttonCount = self.buttonCount + 1
    self.buttonTab[self.buttonCount] = {
        label = label,
        xPos = stx,
        yPos = sty,
        width = w,
        height = h,
        colour = col,
        returnVal = returnVal,
        }
end

--SUBMENU FUNCTIONS--

function screen:addSubMenu(label)
    if self.subTab == nil then
        self.subTab = {}
        self.subCount = 0
    end
    self.subCount = self.subCount + 1
    self.subTab[self.subCount] = {
        label = label,
        open = false,
        }
end

function screen:addSubMenuItem(subMenuLabel, newEntry, retVal)
    for i = 1, #self.subTab do
        if self.subTab[i]["label"] == subMenuLabel then
            if self.subTab[i]["entries"] == nil then
                self.subTab[i]["entries"] = {}
                self.subTab[i]["entryCount"] = 0
            end
            self.subTab[i]["entryCount"] = self.subTab[i]["entryCount"] + 1
            self.subTab[i]["entries"][self.subTab[i]["entryCount"]] = {
                label = newEntry,
                returnVal = retVal,
                }
            return true
        end
    end
end

--TEXT INPUT FUNCTIONS--

function screen:inputBox(identifier, xPos, yPos, width, height, scale)
    xPos = xPos - 1
    yPos = yPos - 1
    self.textInputCount = self.textInputCount + 1
    self:box(xPos + 1, yPos + 1, width, height, white)
    self.textInputs[self.textInputCount] = {
        label = identifier,
        xPos = xPos,
        yPos = yPos,
        width = width,
        height = height,
        scaleable = false,
        bgCol = white,
        fgCol = black,
        selected = false,
        cursorX = 1,
        cursorY = 1,
        }
    self.textInputs[self.textInputCount]["text"] = {}
    if scale ~= nil then
        self.textInputs[self.textInputCount]["scaleable"] = true
        self:box(xPos + 1, yPos + 1, width, height, white, "scale")
    else
        self:box(xPos + 1, yPos + 1, width, height, white)
    end
end

function screen:addText(char)
    for i = 1, #self.textInputs do
        gpu.setBackground(self.textInputs[i]["bgCol"])
        gpu.setForeground(self.textInputs[i]["fgCol"])
        if self.textInputs[i]["selected"] then
            if char == "enter" then
                if self.textInputs[i]["height"] > 1 then
                    gpu.set(self.xPos + (self.textInputs[i]["xPos"] + (self.textInputs[i]["cursorX"] - 1)), self.yPos + (self.textInputs[i]["yPos"] + (self.textInputs[i]["cursorY"] - 1)), " ")
                    if self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] == nil then
                        self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] = " "
                    end
                    self.textInputs[i]["cursorX"] = 1
                    self.textInputs[i]["cursorY"] = self.textInputs[i]["cursorY"] + 1
                    gpu.set(self.xPos + (self.textInputs[i]["xPos"] + (self.textInputs[i]["cursorX"] - 1)), self.yPos + (self.textInputs[i]["yPos"] + (self.textInputs[i]["cursorY"] - 1)), "_")
                end
                if self.textInputs[i]["label"] == "address" then
                    --add some code to launch folder addresses for explorer panes.
                end
                gpu.setBackground(black)
                gpu.setForeground(white)
                return true
            elseif char == "back" then
                if self.textInputs[i]["cursorX"] > 1 then
                    gpu.set(self.xPos + (self.textInputs[i]["xPos"] + (self.textInputs[i]["cursorX"] - 1)), self.yPos + (self.textInputs[i]["yPos"] + (self.textInputs[i]["cursorY"] - 1)), " ")
                    self.textInputs[i]["cursorX"] = self.textInputs[i]["cursorX"] - 1
                    gpu.set(self.xPos + (self.textInputs[i]["xPos"] + (self.textInputs[i]["cursorX"] - 1)), self.yPos + (self.textInputs[i]["yPos"] + (self.textInputs[i]["cursorY"] - 1)), "_")
                    self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] = string.sub(self.textInputs[i]["text"][self.textInputs[i]["cursorY"]], 1, #self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] - 1)
                else
                    if self.textInputs[i]["cursorY"] > 1 then
                        self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] = nil
                        gpu.set(self.xPos + (self.textInputs[i]["xPos"] + (self.textInputs[i]["cursorX"] - 1)), self.yPos + (self.textInputs[i]["yPos"] + (self.textInputs[i]["cursorY"] - 1)), " ")
                        self.textInputs[i]["cursorY"] = self.textInputs[i]["cursorY"] - 1
                        if self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] ~= nil then
                            self.textInputs[i]["cursorX"] = #self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] + 1
                        else
                            self.textInputs[i]["cursorX"] = 1
                        end
                        gpu.set(self.xPos + (self.textInputs[i]["xPos"] + (self.textInputs[i]["cursorX"] - 1)), self.yPos + (self.textInputs[i]["yPos"] + (self.textInputs[i]["cursorY"] - 1)), "_")
                    end
                end
                gpu.setBackground(black)
                gpu.setForeground(white)
                return true
            elseif char == "LSHIFT" or char == "RSHIFT" then
                return true
            else
                if char == "space" then char = " " end
                if char == "1" and keyboard.isShiftDown() == true then char = "!" end
                if char == "2" and keyboard.isShiftDown() == true then char = "\"" end
                if char == "3" and keyboard.isShiftDown() == true then char = "#" end
                if char == "4" and keyboard.isShiftDown() == true then char = "~" end
                if char == "5" and keyboard.isShiftDown() == true then char = "%" end
                if char == "6" and keyboard.isShiftDown() == true then char = "^" end
                if char == "7" and keyboard.isShiftDown() == true then char = "&" end
                if char == "8" and keyboard.isShiftDown() == true then char = "*" end
                if char == "9" and keyboard.isShiftDown() == true then char = "(" end
                if char == "0" and keyboard.isShiftDown() == true then char = ")" end
                if char == "period" then char = "." end
                if char == "numpaddecimal" then char = "." end
                if char == "PERIOD" then char = ">" end
                if char == "comma" then char = "," end
                if char == "COMMA" then char = "<" end
                if char == "apostrophe" then char = "'" end
                if char == "AT" then char = "@" end
                if char == "semicolon" then char = ";" end
                if char == "COLON" then char = ":" end
                if char == "slash" then char = "/" end
                if char == "SLASH" then char = "?" end
                if char == "lbracket" then char = "[" end
                if char == "LBRACKET" then char = "{" end
                if char == "rbracket" then char = "]" end
                if char == "RBRACKET" then char = "}" end
                if char == "UNDERLINE" then char = "_" end
                if char == "equals" then char = "=" end
                if char == "EQUALS" then char = "+" end
                if char == "numpadadd" then char = "+" end
                if char == "minus" or char == "numpadminus" then char = "-" end
                if char == "numpadmul" then char = "*" end
                if char == "CIRCUMFLEX" then char = "^" end
                if char == nil then char = " " end
                if #char > 1 then char = string.sub(char, 1, 1) end
                if self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] ~= nil then
                    self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] = self.textInputs[i]["text"][self.textInputs[i]["cursorY"]]..char
                else
                    self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] = char
                end
                if self.textInputs[i]["label"] == "password" then
                    gpu.set(self.xPos + (self.textInputs[i]["xPos"] + (self.textInputs[i]["cursorX"] - 1)), self.yPos + (self.textInputs[i]["yPos"] + (self.textInputs[i]["cursorY"] - 1)), "*")
                else
                    if self.textInputs[i]["cursorX"] < self.textInputs[i]["width"] - 1 then
                        gpu.set(self.xPos + (self.textInputs[i]["xPos"] + (self.textInputs[i]["cursorX"] - 1)), self.yPos + (self.textInputs[i]["yPos"] + (self.textInputs[i]["cursorY"] - 1)), char)
                        gpu.set(self.xPos + (self.textInputs[i]["xPos"] + self.textInputs[i]["cursorX"]), self.yPos + (self.textInputs[i]["yPos"] + (self.textInputs[i]["cursorY"] - 1)), "_")
                        gpu.setBackground(black)
                        gpu.setForeground(white)
                    end
                end
                self.textInputs[i]["cursorX"] = self.textInputs[i]["cursorX"] + 1
                return true
            end
        end
    end
    gpu.setBackground(black)
    gpu.setForeground(white)
    return false
end

--FILE SYSTEM FUNCTIONS--

function screen:addFileViewer(xPos, yPos, w, h, col, path)
    xPos = xPos - 1
    yPos = yPos - 1
    if self.fileViewer == nil then
        self.fileViewer = {}
        self.fvCount = 0
    end
    self.fvCount = self.fvCount + 1
    self.fileViewer[self.fvCount] = {
        xPos = xPos,
        yPos = yPos,
        width = w,
        height = h,
        colour = col,
        path = path,
        }
    self.fileViewer[self.fvCount]["list"] = {}
    self.fileViewer[self.fvCount]["list"] = self:assembleFileTable(path)
end
    
function screen:assembleFileTable(path)
    local alphaString = "0123456789AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz"
    local pathList, error = fs.list(path)
    local dataTab = {}
    i = 0
    for key in pathList do
        i = i + 1
        if string.sub(key, #key, #key) == "/" then
            key = string.sub(key, 1, #key - 1)
        end
        dataTab[i] = key
    end
    local returnTab = {}
    local rtCount = 0
    for l = 1, #alphaString do
        for i = 1, #dataTab do
            if dataTab[i] ~= nil then
                if fs.isDirectory(path..dataTab[i]) then
                    if string.sub(dataTab[i], 1, 1) == string.sub(alphaString, l, l) then
                        rtCount = rtCount + 1
                        returnTab[rtCount] = dataTab[i]
                        --dataTab[i] = nil
                        i = i - 1
                    end
                end
            end
        end
    end
    for l = 1, #alphaString do
        for i = 1, #dataTab do
            if dataTab[i] ~= nil then
                if not fs.isDirectory(path..dataTab[i]) then
                    if string.sub(dataTab[i], 1, 1) == string.sub(alphaString, l, l) then
                        rtCount = rtCount + 1
                        returnTab[rtCount] = dataTab[i]
                        --dataTab[i] = nil
                        i = i - 1
                        break
                    end
                end
            end
        end
    end
    return returnTab
end

--IMAGE FUNCTIONS--

function screen:newImage(label, xPos, yPos, sizeX, sizeY, trans)
    if self.imTab == nil then
        self.imTab = {}
        self.imCount = 0
    end
    self.imCount = self.imCount + 1
    self.imTab[self.imCount] = {
        label = label,
        xPos = xPos,
        yPos = yPos,
        width = sizeX,
        height = sizeY,
        hidden = false,
        trans = trans,
        layers = 1,
        pages = 1,
    }
    self.imTab[self.imCount]["layerData"] = {}
    self.imTab[self.imCount]["layerData"][1] = {}
    self.imTab[self.imCount]["layerData"][1]["hidden"] = false
    for i = sizeY, 1, -1 do
        self.imTab[self.imCount]["layerData"][1][i] = {}
        for j = 1, sizeX do
            self.imTab[self.imCount]["layerData"][1][i][j] = {
                fg = black,
                bg = white,
                char = " ",
            }
        end
    end
end

function screen:newImageLayer(label)
    local id = 0
    for i = 1, #self.imTab do
        if self.imTab[i]["label"] == label then
            id = i
            break
        end
    end
    if id == 0 then return false end
    self.imTab[id]["layers"] = self.imTab[id]["layers"] + 1
    self.imTab[id]["layerData"][self.imTab[id]["layers"]] = {}
    self.imTab[id]["layerData"][self.imTab[id]["layers"]]["hidden"] = false
    for y = self.imTab[id]["height"], 1, -1 do
        self.imTab[id]["layerData"][self.imTab[id]["layers"]][y] = {}
        for x = 1, self.imTab[id]["width"] do
            self.imTab[id]["layerData"][self.imTab[id]["layers"]][y][x] = {
                bg = "trans",
                fg = 0xFFFFFF,
                char = " ",
                }
        end
    end
    if self.imTab[id]["layers"] % 10 == 0 then
        self.imTab[id]["pages"] = self.imTab[id]["pages"] + 1
    end
end

function screen:saveImage(label, path)
    if self.imTab ~= nil then
        local imId = 0
        for i = 1, #self.imTab do
            if self.imTab[i]["label"] == label then
                file = io.open(path, "w")
                file:write(serial.serialize(self.imTab[i]))
                file:close()
                return true
            end
        end
    end
    return false
end

function screen:loadImage(label, path, x, y)
    x = x - 1
    y = y - 1
    if fs.exists(path) then
        if self.imTab == nil then
            self.imTab = {}
            self.imCount = 0
        end
        self.imCount = self.imCount + 1
        file = io.open(path, "r")
        self.imTab[self.imCount] = serial.unserialize(file:read("*all"))
        file:close()
        self.imTab[self.imCount]["xPos"] = x
        self.imTab[self.imCount]["yPos"] = y
        return true
    end
    return false
end

--RENDER FUNCTIONS--

function screen:renderBoxes()
    if self.boxTab ~= nil then
        for i = 1, #self.boxTab do
            gpu.setBackground(self.boxTab[i]["colour"])
            gpu.fill(self.xPos + self.boxTab[i]["xPos"], self.yPos + self.boxTab[i]["yPos"], self.boxTab[i]["width"], self.boxTab[i]["height"], " ")
        end
    end
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
end

function screen:renderText()
    if self.printTab ~= nil then
        for i = 1, #self.printTab do
            gpu.setBackground(self.printTab[i]["bgCol"])
            gpu.setForeground(self.printTab[i]["tCol"])
            gpu.set(self.xPos + self.printTab[i]["xPos"], self.yPos + self.printTab[i]["yPos"], self.printTab[i]["text"])
        end
    end
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
end

function screen:renderTextBoxes()
    if self.textBox ~= nil then
        for i = 1, #self.textBox do
            gpu.setBackground(self.textBox[i]["bgCol"])
            gpu.setForeground(self.textBox[i]["tCol"])
            if self.textBox[i]["lineCount"] >= self.textBox[i]["height"] then
                startLine = #self.textBox[i]["line"] - (self.textBox[i]["height"] - 2)
            else
                startLine = 1
            end
            curLine = 0
            for j = startLine, #self.textBox[i]["line"] do
                printLine = self.textBox[i]["line"][j]
                if #printLine > self.textBox[i]["width"] then
                    printLine = string.sub(printLine, #printLine - self.textInputs[i]["width"], #printLine)
                end
                gpu.set(self.xPos + self.textBox[i]["xPos"], self.yPos + (self.textBox[i]["yPos"] + (curLine)), printLine)
                curLine = curLine + 1
            end
        end
    end
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
end

function screen:renderButtons()
    if self.buttonTab ~= nil then
        gpu.setForeground(black)
        for i = 1, #self.buttonTab do
            gpu.setBackground(self.buttonTab[i]["colour"])
            gpu.fill(self.xPos + self.buttonTab[i]["xPos"], self.yPos + self.buttonTab[i]["yPos"], self.buttonTab[i]["width"], self.buttonTab[i]["height"], " ")
            midLine = math.floor(self.buttonTab[i]["height"] / 2)
            printLine = self.buttonTab[i]["label"]
            if #printLine > self.buttonTab[i]["width"] then
                printLine = string.sub(printLine, 1, self.buttonTab[i]["width"])
            end
            offset = math.floor((self.buttonTab[i]["width"] - #printLine) / 2)
            gpu.set(self.xPos + (self.buttonTab[i]["xPos"] + offset), self.yPos + (self.buttonTab[i]["yPos"] + midLine), printLine)
        end
    end
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
end

function screen:renderTextInputs()
    if self.textInputs ~= nil then
        for i = 1, #self.textInputs do
            if self.textInputs[i]["text"] ~= nil then
                gpu.setBackground(self.textInputs[i]["bgCol"])
                gpu.setForeground(self.textInputs[i]["fgCol"])
                if self.textInputs[i]["cursorY"] > self.textInputs[i]["height"] then
                    startLine = self.textInputs[i]["cursorY"] - self.textInputs[i]["height"]
                else
                    startLine = 1
                end
                for j = startLine, #self.textInputs[i]["text"] do
                    printLine = self.textInputs[i]["text"][j]
                    if #printLine > self.textInputs[i]["width"] then
                        printLine = string.sub(printLine, #printLine - (self.textInputs[i]["width"] - 2), #printLine)
                    end
                    if self.textInputs[i]["label"] ~= "password" then
                        gpu.set(self.xPos + self.textInputs[i]["xPos"], self.yPos + (self.textInputs[i]["yPos"] + (j - 1)), printLine)
                    else
                        for k = 1, #printLine do
                            gpu.set(self.xPos + (self.textInputs[i]["xPos"] + (k - 1)), self.yPos + self.textInputs[i]["yPos"], "*")
                        end
                    end
                end
            end
        end
    end
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
end

function screen:renderSubMenus()
    if self.subTab ~= nil then
        local w, h = gpu.getResolution()
        local newOffset = 2
        for i = 1, #self.subTab do
            if self.subTab[i]["open"] then
                gpu.setBackground(0x666666)
                gpu.setForeground(0x000000)
                gpu.set(self.xPos + newOffset, self.yPos + 1, self.subTab[i]["label"])
                gpu.setBackground(0x999999)
                gpu.setForeground(0x000000)
                local maxLength = 0
                for j = 1, #self.subTab[i]["entries"] do
                    if #self.subTab[i]["entries"][j]["label"] > maxLength then
                        maxLength = #self.subTab[i]["entries"][j]["label"]
                    end
                end
                gpu.fill(self.xPos + newOffset, self.yPos + 2, maxLength + 1, #self.subTab[i]["entries"], " ")
                for j = 1, #self.subTab[i]["entries"] do
                    if self.yPos > h / 2 then
                        gpu.set(self.xPos + newOffset, self.yPos - (j + 1), self.subTab[i]["entries"][j]["label"])
                    else
                        gpu.set(self.xPos + newOffset, self.yPos + (j + 1), self.subTab[i]["entries"][j]["label"])
                    end
                end
            else
                gpu.setBackground(0x999999)
                gpu.setForeground(0x000000)
                gpu.set(self.xPos + newOffset, self.yPos + 1, self.subTab[i]["label"])
            end
            newOffset = newOffset + (#self.subTab[i]["label"] + 1)
        end
    end
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
end

function screen:renderFileLists()
    if self.fileViewer ~= nil then
        gpu.setForeground(white)
        gpu.setForeground(black)
        for i = 1, #self.fileViewer do
            gpu.setBackground(white)
            gpu.fill(self.xPos + self.fileViewer[i]["xPos"], self.yPos + self.fileViewer[i]["yPos"], self.fileViewer[i]["width"], self.fileViewer[i]["height"], " ")
            for j = 1, #self.fileViewer[i]["list"] do
                if fs.isDirectory(self.fileViewer[i]["path"]..self.fileViewer[i]["list"][j].."/") then
                    gpu.setBackground(0xFF9900)
                    gpu.set(self.xPos + self.fileViewer[i]["xPos"], self.yPos + (self.fileViewer[i]["yPos"] + j), "¬")
                else
                    gpu.setBackground(0xCCCCCC)
                    gpu.set(self.xPos + self.fileViewer[i]["xPos"], self.yPos + (self.fileViewer[i]["yPos"] + j), "=")
                end
                gpu.setBackground(0xFFFFFF)
                gpu.set(self.xPos + (self.fileViewer[i]["xPos"] + 1), self.yPos + (self.fileViewer[i]["yPos"] + j), self.fileViewer[i]["list"][j])
            end
        end
    end
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
end

function screen:compileLineTable(id, layer, line)
    local curBg = self.imTab[id]["layerData"][layer][line][1]["bg"]
    local curFg = self.imTab[id]["layerData"][layer][line][1]["fg"]
    local curSt = self.imTab[id]["layerData"][layer][line][1]["char"]
    local stx = self.xPos + (self.imTab[id]["xPos"] - 1)
    local sty = self.yPos + ((self.imTab[id]["yPos"] - 1) + (line - 1))
    local colCount = 0
    local pTab = {}
    for i = 1, #self.imTab[id]["layerData"][layer][line] do
        curBg = self.imTab[id]["layerData"][layer][line][i]["bg"]
        curFg = self.imTab[id]["layerData"][layer][line][i]["fg"]
        curSt = self.imTab[id]["layerData"][layer][line][i]["char"]
        if curBg == "trans" then
            for x = layer, 1, -1 do
                if not self.imTab[id]["layerData"][x]["hidden"] then
                    if self.imTab[id]["layerData"][x][line][i]["bg"] ~= "trans" then
                        curBg = self.imTab[id]["layerData"][x][line][i]["bg"]
                    end
                elseif self.running then
                    if x == 1 then
                        curBg = self.imTab[id]["layerData"][x][line][i]["bg"]
                    end
                end
            end
        end
        if i == 1 or curBg ~= pTab[colCount]["bg"] or curFg ~= pTab[colCount]["fg"] then
            colCount = colCount + 1
            pTab[colCount] = {
                bg = curBg,
                fg = curFg,
                st = curSt,
                yp = sty,
                xp = stx,
            }
        else
            pTab[colCount]["st"] = pTab[colCount]["st"]..curSt
        end
        stx = stx + 1
    end
    return(pTab)
end

function screen:renderImages()
    local prTab = 0
    if self.imTab ~= nil then
        for i = 1, #self.imTab do
            for l = 1, #self.imTab[i]["layerData"] do
                if not self.imTab[i]["layerData"][l]["hidden"] then
                    for r = #self.imTab[i]["layerData"][l], 1, -1 do
                        prTab = self:compileLineTable(i, l, r)
                        for p = 1, #prTab do
                            if prTab[p]["bg"] ~= "trans" then
                                gpu.setBackground(prTab[p]["bg"])
                                gpu.setForeground(prTab[p]["fg"])
                                gpu.set(prTab[p]["xp"], prTab[p]["yp"], prTab[p]["st"])
                            end
                        end
                    end
                end
            end
        end
    end
end

function screen:render()
    if not self.renderBool then return end
    self:renderBoxes()
    self:renderTextBoxes()
    self:renderButtons()
    self:renderTextInputs()
    self:renderSubMenus()
    self:renderFileLists()
    self:renderImages()
    self:renderText()
end

--PAINT PROGRAM START--

--CONSTANTS--

scrx, scry = gpu.getResolution()
local buttonWidth = 20
local vTab = {
    [1] = "00",
    [2] = "33",
    [3] = "66",
    [4] = "99",
    [5] = "CC",
    [6] = "FF",
    }

--ARGUMENTS--

args = {...}
filename = args[1]
width = tonumber(args[2])
height = tonumber(args[3])
if filename == nil then filename = "Untitled" end
if width == nil then width = scrx end
if height == nil then height = scry end

--VARIABLES--

local fgCur = 0x000000
local fgLast = 0x000000
local bgCur = 0xFFFFFF
local bgLast = 0xFFFFFF
local charCur = " "
local charLast = " "
local activeLayer = 1
local activePalette = 1
local activePalette = 1
local pEntry = 1
local fgBool = false
local bgBool = true
local charBool = false
local menuBool = true
local paletteBool = false
local colourBool = false
local browserBool = false
local toolBool = false
local layerBool = false
local playerBool = false
local rcl = screen:newPane(rcl, 15, 14)
local pTab = screen:newPane(pTab, 28, 14)
local colour = screen:newPane(colour, 13, 14)
local tools = screen:newPane(tools, 15, 14)
local layers = screen:newPane(layers, 15, 19)
local player = screen:newPane(player, 15, 6)

--OBJECT CALL FUNCTIONS--

function newImage(sizeX, sizeY)
    local ob = screen:newPane(ob, sizeX, sizeY)
    ob:newImage(filename, 1, 1, sizeX, sizeY)
    ob:center()
    return(ob)
end

function newLayer() --needs writing.
    
end

function rClickMenuSetup()
    rcl:box(1, 1, rcl.width, rcl.height, 0x999999)
    rcl:box(1, 1, rcl.width, 1, 0x00CCCC)
    rcl:centerText(1, 1, rcl.width, 0x00CCCC, 0x000000, "Menu")
    rcl.xPos = 1
    rcl.yPos = 1
end

function paletteSetup()
    pTab.xPos = scrx - pTab.width
    pTab.yPos = 1
    pTab:box(1, 1, pTab.width, pTab.height, 0x999999)
    pTab:box(1, 1, pTab.width, 1, 0x00CCCC)
    pTab:centerText(1, 1, pTab.width, 0x00CCCC, 0x000000, "Colour Palette")
    pTab.pCount = 1
    pTab.list = {}
    pTab.list[1] = {}
    pTab.list[1][1] = 0x000000
    pTab.list[1][2] = 0xFFFFFF
    pTab.list[1][3] = 0xFF0000
    pTab.list[1][4] = 0x00FF00
    pTab.list[1][5] = 0x0000FF
    pTab.list[1][6] = 0xFF00FF
    pTab.list[1][7] = 0xFFFF00
    pTab.list[1][8] = 0x00FFFF
    pTab.list[1][9] = 0x00CCCC
end

function newPalette()
    pTab.pCount = pTab.pCount + 1
    pTab.list[pTab.pCount] = {}
    for i = 1, 9 do
        pTab.list[pTab.pCount][i] = 0xFFFFFF
    end
end

function colourSetup()
    colour:center()
    colour:box(1, 1, colour.width, colour.height, 0x999999)
    colour:box(1, 1, colour.width, 1, 0x00CCCC)
    colour:centerText(1, 1, colour.width, 0x00CCCC, 0x000000, "RGB Edit")
    colour.rVal = 6
    colour.gVal = 6
    colour.bVal = 6
end

function toolBox()
    tools:center()
    tools:box(1, 1, tools.width, tools.height, 0x999999, "scale")
    tools:box(1, 1, tools.width, 1, 0x00CCCC, "scale")
    tools:centerText(1, 1, tools.width, 0x00CCCC, 0x000000, "Tools")
    tools.brush = {
        active = true,
        sizeX = 1,
        sizeY = 1,
    }
    tools.line = {
        active = false,
        startx = 0,
        starty = 0,
        endx = 0,
        endy = 0,
    }
    tools.boxTool = {
        active = false,
        startx = 0,
        starty = 0,
        endx = 0,
        endy = 0,
    }
    tools.circle = {
        active = false,
        radius = 1,
        solid = false,
    }
end

function fileBrowser(col, name)
    local object = screen:newPane(object, 30, 15)
    object.selected = false
    object.priority = 9
    object.label = name
    object.isPane = true
    object.colour = col
    object:center()
    object:box(1, 1, object.width, object.height, 0x999999, "scale")
    object:box(1, 1, object.width, 1, col, "scale")
    object:centerText(1, 1, object.width, col, 0x000000, object.label)
    object:box(2, 5, object.width - 2, object.height - 5, 0xFFFFFF, "scale")
    object:addFileViewer(2, 5, object.width - 2, object.height - 5, 0xFFFFFF, path.."/Images/")
    object:text(2, 3, 0x999999, 0x000000, "Path:")
    object:inputBox("address", 8, 3, object.width - 10, 1, "scale")
    object:button("^", object.width - 2, 3, 1, 1, 0x00CCCC, "navigate_up")
    object.textInputs[1]["text"][1] = object.fileViewer[1]["path"]
    object.fileViewer[1]["list"] = object:assembleFileTable(object.fileViewer[1]["path"])
    object.textInputs[1]["cursorX"] = #object.textInputs[1]["text"][1] + 1
    return object
end

function layerTool()
    layers:center()
    layers:box(1, 1, layers.width, layers.height, 0x999999, "scale")
    layers:box(1, 1, layers.width, 1, 0x00CCCC, "scale")
    layers:centerText(1, 1, layers.width, 0x00CCCC, 0x000000, "Layers")
    layers.lPage = 1
    layers.transBool = false
end

function initPlayer()
    player:center()
    player:box(1, 1, player.width, player.height, 0x999999, "scale")
    player:box(1, 1, player.width, 1, 0x00CCCC, "scale")
    player:centerText(1, 1, player.width, 0x00CCCC, 0x000000, "Animator")
    player.loop = false
    player.play = false
end

--DRAW FUNCTIONS--

function renderRClick()
    if menuBool then
        rcl.buttonTab = nil
        if paletteBool then
            rcl:button("Palette", 2, 3, rcl.width - 2, 1, 0x0099CC, "pSwitch")
        else
            rcl:button("Palette", 2, 3, rcl.width - 2, 1, 0x00CCCC, "pSwitch")
        end
        if toolBool then
            rcl:button("Tools", 2, 5, rcl.width - 2, 1, 0x0099CC, "tSwitch")
        else
            rcl:button("Tools", 2, 5, rcl.width - 2, 1, 0x00CCCC, "tSwitch")
        end
        if layerBool then
            rcl:button("Layers", 2, 7, rcl.width - 2, 1, 0x0099CC, "layers")
        else
            rcl:button("Layers", 2, 7, rcl.width - 2, 1, 0x00CCCC, "layers")
        end
        if playerBool then
            rcl:button("Animate", 2, 9, rcl.width - 2, 1, 0x0099CC, "animate")
        else
            rcl:button("Animate", 2, 9, rcl.width - 2, 1, 0x00CCCC, "animate")
        end
        rcl:button("Save", 2, 11, rcl.width - 2, 1, 0x00CCCC, "save")
        rcl:button("Load", 2, 13, rcl.width - 2, 1, 0x00CCCC, "load")
        rcl:render()
    end
end

function drawPalette(active)
    if paletteBool then
        local pStr = active.."/"..pTab.pCount
        if pTab.width < 23 then pTab.width = 23 end
        local navx = math.floor((pTab.width - 21) / 2)
        pTab.buttonTab = nil
        pTab:button("New", navx, 3, 5, 1, 0x00CCCC, "add_palette")
        pTab:button("<", navx + 6, 3, 3, 1, 0x00CCCC, "bk_palette")
        pTab:button(pStr, navx + 10, 3, 8, 1, 0xFFFFFF, "never_mind_this")
        pTab:button(">", navx + 19, 3, 3, 1, 0x00CCCC, "fd_palette")
        navx = math.floor((pTab.width - 17) / 2)
        if fgBool then
            pTab:button("FG", navx, 5, 5, 1, 0x0099CC, "fg")
        else
            pTab:button("FG", navx, 5, 5, 1, 0x00CCCC, "fg")
        end
        if bgBool then
            pTab:button("BG", navx + 6, 5, 5, 1, 0x0099CC, "bg")
        else
            pTab:button("BG", navx + 6, 5, 5, 1, 0x00CCCC, "bg")
        end
        if charBool then
            pTab:button("Char", navx + 12, 5, 5, 1, 0x0099CC, "char")
        else
            pTab:button("Char", navx + 12, 5, 5, 1, 0x00CCCC, "char")
        end
        pTab:button(" ", navx, 7, 5, 1, fgCur, "fg")
        if bgCur ~= "trans" then
            pTab:button(" ", navx + 6, 7, 5, 1, bgCur, "bg")
            pTab:button(" ", navx + 12, 7, 5, 1, bgCur, "char")
        else
            pTab:button("TR", navx + 6, 7, 5, 1, 0xFFFFFF, "bg")
            pTab:button(" ", navx + 12, 7, 5, 1, 0xFFFFFF, "char")
        end
        local xPos = 2
        local yPos = 9
        local bWidth = math.floor((pTab.width - 4) / 3)
        local bHeight = math.floor((pTab.height - 9) / 3)
        for i = 1, #pTab.list[active] do
            if pTab.list[active][i] ~= nil then
                col = pTab.list[active][i]
            else
                col = 0xFFFFFF
            end
            pTab:button(charCur, xPos, yPos, bWidth, bHeight, col, i)
            if i % 3 == 0 then
                xPos = 2
                yPos = yPos + (bHeight + 1)
            else
                xPos = xPos + (bWidth + 1)
            end
        end
        pTab:render()
    end
end

function colourChanger()
    if colourBool then
        colour.buttonTab = nil
        if colour.rVal < 6 then
            colour:button("^", 2, 3, 3, 1, 0x00CCCC, "r_plus")
        else
            colour:button("^", 2, 3, 3, 1, 0x0099CC, "r_plus")
        end
        colour:button(vTab[colour.rVal], 2, 5, 3, 1, 0xFFFFFF, "no_action")
        if colour.rVal > 1 then
            colour:button("v", 2, 7, 3, 1, 0x00CCCC, "r_minus")
        else
            colour:button("v", 2, 7, 3, 1, 0x0099CC, "r_minus")
        end
        if colour.gVal < 6 then
            colour:button("^", 6, 3, 3, 1, 0x00CCCC, "g_plus")
        else
            colour:button("^", 6, 3, 3, 1, 0x0099CC, "g_plus")
        end
        colour:button(vTab[colour.gVal], 6, 5, 3, 1, 0xFFFFFF, "no_action")
        if colour.gVal > 1 then
            colour:button("v", 6, 7, 3, 1, 0x00CCCC, "g_minus")
        else
            colour:button("v", 6, 7, 3, 1, 0x0099CC, "g_minus")
        end
        if colour.bVal < 6 then
            colour:button("^", 10, 3, 3, 1, 0x00CCCC, "b_plus")
        else
            colour:button("^", 10, 3, 3, 1, 0x0099CC, "b_plus")
        end
        colour:button(vTab[colour.bVal], 10, 5, 3, 1, 0xFFFFFF, "no_action")
        if colour.bVal > 1 then
            colour:button("v", 10, 7, 3, 1, 0x00CCCC, "b_minus")
        else
            colour:button("v", 10, 7, 3, 1, 0x0099CC, "b_minus")
        end
        colour:button("0x"..vTab[colour.rVal]..vTab[colour.gVal]..vTab[colour.bVal], 2, 9, colour.width - 2, 3, tonumber("0x"..vTab[colour.rVal]..vTab[colour.gVal]..vTab[colour.bVal]), "no_action")
        colour:button("Ok", 2, 13, 5, 1, 0x00CCCC, "set_colour")
        colour:button("Exit", 8, 13, 5, 1, 0x00CCCC, "exit")
        colour:render()
    end
end

function drawToolBox()
    if toolBool then
        tools.buttonTab = nil
        tools.printTab = nil
        tools:centerText(1, 1, tools.width, 0x00CCCC, 0x000000, "Tools")
        if tools.brush["active"] then
            tools:resize(15, 11)
            tools:centerText(1, 7, tools.width, 0x999999, 0x000000, "Width")
            tools:centerText(1, 9, tools.width, 0x999999, 0x000000, "Height")
            tools:button("Brush", 2, 3, 6, 1, 0x0099CC, "brSwitch")
            if tools.brush["sizeX"] > 1 then
                tools:button("<", 2, 8, 3, 1, 0x00CCCC, "brx_minus")
                tools:button(tostring(tools.brush["sizeX"]), 6, 8, 5, 1, 0xFFFFFF, "no_action")
                tools:button(">", 12, 8, 3, 1, 0x00CCCC, "brx_plus")
            else
                tools:button("<", 2, 8, 3, 1, 0x0099CC, "brx_minus")
                tools:button(tostring(tools.brush["sizeX"]), 6, 8, 5, 1, 0xFFFFFF, "no_action")
                tools:button(">", 12, 8, 3, 1, 0x00CCCC, "brx_plus")
            end
            if tools.brush["sizeY"] > 1 then
                tools:button("<", 2, 10, 3, 1, 0x00CCCC, "bry_minus")
                tools:button(tostring(tools.brush["sizeY"]), 6, 10, 5, 1, 0xFFFFFF, "no_action")
                tools:button(">", 12, 10, 3, 1, 0x00CCCC, "bry_plus")
            else
                tools:button("<", 2, 10, 3, 1, 0x0099CC, "bry_minus")
                tools:button(tostring(tools.brush["sizeY"]), 6, 10, 5, 1, 0xFFFFFF, "no_action")
                tools:button(">", 12, 10, 3, 1, 0x00CCCC, "bry_plus")
            end
        else
            tools:button("Brush", 2, 3, 6, 1, 0x00CCCC, "brSwitch")
        end
        if tools.line["active"] then
            tools:resize(15, 15)
            tools:centerText(1, 7, tools.width, 0x999999, 0x000000, "X Start")
            tools:centerText(1, 9, tools.width, 0x999999, 0x000000, "Y Start")
            tools:centerText(1, 11, tools.width, 0x999999, 0x000000, "X End")
            tools:centerText(1, 13, tools.width, 0x999999, 0x000000, "Y End")
            tools:button("Line", 9, 3, 6, 1, 0x0099CC, "lSwitch")
            tools:button(tostring(tools.line["startx"]), 2, 8, tools.width - 2, 1, 0xFFFFFF, "no_action")
            tools:button(tostring(tools.line["starty"]), 2, 10, tools.width - 2, 1, 0xFFFFFF, "no_action")
            tools:button(tostring(tools.line["endx"]), 2, 12, tools.width - 2, 1, 0xFFFFFF, "no_action")
            tools:button(tostring(tools.line["endy"]), 2, 14, tools.width - 2, 1, 0xFFFFFF, "no_action")
        else
            tools:button("Line", 9, 3, 6, 1, 0x00CCCC, "lSwitch")
        end
        if tools.boxTool["active"] then
            tools:resize(15, 15)
            tools:centerText(1, 7, tools.width, 0x999999, 0x000000, "X Start")
            tools:centerText(1, 9, tools.width, 0x999999, 0x000000, "Y Start")
            tools:centerText(1, 11, tools.width, 0x999999, 0x000000, "X End")
            tools:centerText(1, 13, tools.width, 0x999999, 0x000000, "Y End")
            tools:button("Box", 2, 5, 6, 1, 0x0099CC, "bSwitch")
            tools:button(tostring(tools.line["startx"]), 2, 8, tools.width - 2, 1, 0xFFFFFF, "no_action")
            tools:button(tostring(tools.line["starty"]), 2, 10, tools.width - 2, 1, 0xFFFFFF, "no_action")
            tools:button(tostring(tools.line["endx"]), 2, 12, tools.width - 2, 1, 0xFFFFFF, "no_action")
            tools:button(tostring(tools.line["endy"]), 2, 14, tools.width - 2, 1, 0xFFFFFF, "no_action")
        else
            tools:button("Box", 2, 5, 6, 1, 0x00CCCC, "bSwitch")
        end
        if tools.circle["active"] then
            tools:resize(15, 11)
            tools:button("Circle", 9, 5, 6, 1, 0x0099CC, "cSwitch")
            tools:centerText(1, 7, tools.width, 0x999999, 0x000000, "Radius")
            if tools.circle["radius"] > 1 then
                tools:button("<", 2, 8, 3, 1, 0x00CCCC, "rad_minus")
                tools:button(tostring(tools.circle["radius"]), 6, 8, 5, 1, 0xFFFFFF, "no_action")
                tools:button(">", 12, 8, 3, 1, 0x00CCCC, "rad_plus")
            else
                tools:button("<", 2, 8, 3, 1, 0x0099CC, "rad_minus")
                tools:button(tostring(tools.circle["radius"]), 6, 8, 5, 1, 0xFFFFFF, "no_action")
                tools:button(">", 12, 8, 3, 1, 0x00CCCC, "rad_plus")
            end
            if tools.circle["solid"] then
                tools:button("Filled", 2, 10, tools.width - 2, 1, 0x0099CC, "toggle_filled")
            else
                tools:button("Filled", 2, 10, tools.width - 2, 1, 0x00CCCC, "toggle_filled")
            end
        else
            tools:button("Circle", 9, 5, 6, 1, 0x00CCCC, "cSwitch")
        end
        tools:render()
    end
end

function drawLayerMenu()
    if layerBool then
        layers.buttonTab = nil
        if layers.transBool then
            layers:button("Trans", 2, 3, layers.width - 2, 1, 0x0099CC, "trans_toggle")
        else
            layers:button("Trans", 2, 3, layers.width - 2, 1, 0x00CCCC, "trans_toggle")
        end
        if layers.lPage == 1 then
            layers:button("<", 2, 5, 3, 1, 0x0099CC, "page_down")
        else
            layers:button("<", 2, 5, 3, 1, 0x00CCCC, "page_down")
        end
        layers:button(tostring(layers.lPage).."/"..tostring(image.imTab[1]["pages"]), 6, 5, 5, 1, 0xFFFFFF, "page_down")
        if layers.lPage < image.imTab[1]["pages"] then
            layers:button(">", layers.width - 3, 5, 3, 1, 0x00CCCC, "page_up")
        else
            layers:button(">", layers.width - 3, 5, 3, 1, 0x0099CC, "page_up")
        end
        layers:button("New Layer", 2, 7, layers.width - 2, 1, 0x00CCCC, "new_layer")
        local yoffset = 1
        for i = (layers.lPage * 10) - 9, layers.lPage * 10 do
            if image.imTab[1]["layerData"][i] ~= nil then
                if i == activeLayer then
                    layers:button(tostring(i), 2, 8 + yoffset, layers.width - 6, 1, 0x6666FF, i)
                else
                    layers:button(tostring(i), 2, 8 + yoffset, layers.width - 6, 1, 0xFFFFFF, i)
                end
                if image.imTab[1]["layerData"][i]["hidden"] then
                    layers:button("H", layers.width - 3, 8 + yoffset, 3, 1, 0xCC0000, "show_"..tostring(i))
                else
                    layers:button("V", layers.width - 3, 8 + yoffset, 3, 1, 0x00CC00, "hide_"..tostring(i))
                end
            end
            yoffset = yoffset + 1
        end
        layers:render()
    end
end

function drawScreen(clear)
    if clear ~= nil then
        gpu.setForeground(0xFFFFFF)
        gpu.setBackground(0x000000)
        term.clear()
    end
    image:renderImages()
    drawPalette(activePalette)
    drawToolBox()
    colourChanger()
    if browserBool then browser:render() end
    drawLayerMenu()
    drawRemote()
    renderRClick()
    gpu.setForeground(0xFFFFFF)
    gpu.setBackground(0x000000)
end

function drawRemote()
    if playerBool then
        player.buttonTab = nil
        if player.play then
            player:button("Play", 2, 3, 6, 3, 0x0099CC, "play")
        else
            player:button("Play", 2, 3, 6, 3, 0x00CCCC, "play")
        end
        if player.loop then
            player:button("Loop", 9, 3, 6, 3, 0x0099CC, "loop")
        else
            player:button("Loop", 9, 3, 6, 3, 0x00CCCC, "loop")
        end
        player:render()
    end
end

function playVideo()
    gpu.setForeground(0xFFFFFF)
    gpu.setBackground(0x000000)
    term.clear()
    image.running = true
    while image.running do
        for al = 1, #image.imTab[1]["layerData"] do
            for i = 1, #image.imTab[1]["layerData"] do
                image.imTab[1]["layerData"][i]["hidden"] = true
            end
            image.imTab[1]["layerData"][al]["hidden"] = false
            image:render()
        end
        if not player.loop then
            image.running = false
            break
        end
        run()
    end
    for i = 1, #image.imTab[1]["layerData"] do
        image.imTab[1]["layerData"][i]["hidden"] = true
    end
    image.imTab[1]["layerData"][1]["hidden"] = false
    image.imTab[1]["layerData"][activeLayer]["hidden"] = false
    drawScreen("c")
end

--RUN LOOP--

function checkImage(ev, clx, cly, pl, btn)
    local modifier = 1.5
    if btn == 0 then
        if ev == "touch" or ev == "drag" then
            local imStx = image.xPos + (image.imTab[1]["xPos"] - 1)
            local imSty = image.yPos + (image.imTab[1]["yPos"] - 1)
            local imMax = imStx + (image.imTab[1]["width"] - 1)
            local imMay = imSty + (image.imTab[1]["height"] - 1)
            local imClx = clx - (imStx - 1)
            local imCly = cly - (imSty - 1)
            if clx >= imStx and clx <= imMax then
                if cly >= imSty and cly <= imMay then
                    gpu.setForeground(fgCur)
                    if bgCur ~= "trans" then
                        gpu.setBackground(bgCur)
                    end
                    if tools.brush["active"] then
                        for y = 1, tools.brush["sizeY"] do
                            for x = 1, tools.brush["sizeX"] do
                                if imCly - (y - 1) >= 1 and imCly + (y - 1) <= image.height then
                                    if imClx - (x - 1) >= 1 and imClx + (x - 1) <= image.width then
                                        if image.imTab[1]["layerData"][activeLayer][imCly - (y - 1)][imClx - (x - 1)] ~= nil then
                                            if x + y <= math.ceil((tools.brush["sizeX"] + tools.brush["sizeY"]) / modifier) then
                                                image.imTab[1]["layerData"][activeLayer][imCly - (y - 1)][imClx - (x - 1)]["bg"] = bgCur
                                                gpu.set(clx - (x - 1), cly - (y - 1), charCur)
                                            end
                                        end
                                        if image.imTab[1]["layerData"][activeLayer][imCly + (y - 1)][imClx + (x - 1)] ~= nil then
                                            if x + y <= math.ceil((tools.brush["sizeX"] + tools.brush["sizeY"]) / modifier) then
                                                image.imTab[1]["layerData"][activeLayer][imCly + (y - 1)][imClx + (x - 1)]["bg"] = bgCur
                                                gpu.set(clx + (x - 1), cly + (y - 1), charCur)
                                            end
                                        end
                                        if image.imTab[1]["layerData"][activeLayer][imCly + (y - 1)][imClx - (x - 1)] ~= nil then
                                            if x + y <= math.ceil((tools.brush["sizeX"] + tools.brush["sizeY"]) / modifier) then
                                                image.imTab[1]["layerData"][activeLayer][imCly + (y - 1)][imClx - (x - 1)]["bg"] = bgCur
                                                gpu.set(clx + (x - 1), cly - (y - 1), charCur)
                                            end
                                        end
                                        if image.imTab[1]["layerData"][activeLayer][imCly - (y - 1)][imClx + (x - 1)] ~= nil then
                                            if x + y <= math.ceil((tools.brush["sizeX"] + tools.brush["sizeY"]) / modifier) then
                                                image.imTab[1]["layerData"][activeLayer][imCly - (y - 1)][imClx + (x - 1)]["bg"] = bgCur
                                                gpu.set(clx - (x - 1), cly + (y - 1), charCur)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    elseif tools.line["active"] then
                        if tools.line["startx"] == 0 and tools.line["starty"] == 0 then
                            tools.line["startx"] = imClx
                            tools.line["starty"] = imCly
                            drawScreen()
                            gpu.setBackground(0x00FF00)
                            gpu.set(clx, cly, " ")
                            gpu.setBackground(0x000000)
                            return true
                        elseif tools.line["endx"] == 0 and tools.line["endy"] == 0 then
                            tools.line["endx"] = imClx
                            tools.line["endy"] = imCly
                            local difx = (math.max(tools.line["startx"], tools.line["endx"]) - math.min(tools.line["startx"], tools.line["endx"])) + 1
                            local dify = (math.max(tools.line["starty"], tools.line["endy"]) - math.min(tools.line["starty"], tools.line["endy"])) + 1
                            local xPos = tools.line["startx"]
                            local yPos = tools.line["starty"]
                            local xmod = 1
                            local ymod = 1
                            local xoff = 0
                            if tools.line["startx"] > tools.line["endx"] then xmod = -1 end
                            if tools.line["starty"] > tools.line["endy"] then ymod = -1 end
                            for y = 1, dify do
                                if difx == 1 then
                                    image.imTab[1]["layerData"][activeLayer][yPos][xPos]["bg"] = bgCur
                                else
                                    for i = 1, math.floor(math.max(difx, dify) / math.min(difx, dify)) do
                                        image.imTab[1]["layerData"][activeLayer][yPos][xPos]["bg"] = bgCur
                                        xPos = xPos + xmod
                                    end
                                end
                                yPos = yPos + ymod
                            end
                            tools.line["startx"] = 0
                            tools.line["starty"] = 0
                            tools.line["endx"] = 0
                            tools.line["endy"] = 0
                            drawScreen()
                            return true
                        end
                    elseif tools.boxTool["active"] then
                        if tools.boxTool["startx"] == 0 and tools.boxTool["starty"] == 0 then
                            tools.boxTool["startx"] = imClx
                            tools.boxTool["starty"] = imCly
                            drawScreen()
                            gpu.setBackground(0xFF0000)
                            gpu.set(clx, cly, " ")
                            gpu.setBackground(0x000000)
                            return true
                        elseif tools.boxTool["endx"] == 0 and tools.boxTool["endy"] == 0 then
                            tools.boxTool["endx"] = imClx
                            tools.boxTool["endy"] = imCly
                            local minx = math.min(tools.boxTool["startx"], tools.boxTool["endx"])
                            local maxx = math.max(tools.boxTool["startx"], tools.boxTool["endx"])
                            local miny = math.min(tools.boxTool["starty"], tools.boxTool["endy"])
                            local maxy = math.max(tools.boxTool["starty"], tools.boxTool["endy"])
                            for y = miny, maxy do
                                for x = minx, maxx do
                                    image.imTab[1]["layerData"][activeLayer][y][x]["bg"] = bgCur
                                end
                            end
                            tools.boxTool["startx"] = 0
                            tools.boxTool["starty"] = 0
                            tools.boxTool["endx"] = 0
                            tools.boxTool["endy"] = 0
                            drawScreen()
                            return true
                        end
                    elseif tools.circle["active"] then
                        for r = 1, tools.circle["radius"] do
                            if not tools.circle["solid"] then r = tools.circle["radius"] end
                            for j = 1, 360 do
                                local angle = (j * math.pi) / 180
                                local ptx, pty = clx + (r * math.cos(angle)), (cly + (r * math.sin(angle)) / 2)
                                if math.floor(pty) - imSty >= 1 and math.floor(pty) - imSty <= image.height then
                                    if math.floor(ptx) - imStx >= 1 and math.floor(ptx) - imStx <= image.width then
                                        image.imTab[1]["layerData"][activeLayer][math.floor(pty) - imSty][math.floor(ptx) - imStx]["bg"] = bgCur
                                    end
                                end
                            end
                            if not tools.circle["solid"] then break end
                        end
                        drawScreen()
                    end
                end
            end
        end
    end
    return false
end

function checkRCL(ev, clx, cly, pl, btn)
    if menuBool then
        if clx >= rcl.xPos and clx <= rcl.xPos + rcl.width then
            if cly <= rcl.yPos and cly <= rcl.yPos + rcl.height then
                rcl.grabbed = true
            end
        end
        if ev == "touch" then
            for i = 1, #rcl.buttonTab do
                local stx = rcl.xPos + rcl.buttonTab[i]["xPos"]
                local sty = rcl.yPos + (rcl.buttonTab[i]["yPos"] - 1)
                local max = stx + rcl.buttonTab[i]["width"]
                local may = sty + rcl.buttonTab[i]["height"]
                if clx >= stx and clx <= max then
                    if cly >= sty and cly <= may then
                        if rcl.buttonTab[i]["returnVal"] == "pSwitch" then
                            paletteBool = not paletteBool
                            colourBool = false
                            drawScreen("c")
                        elseif rcl.buttonTab[i]["returnVal"] == "tSwitch" then
                            toolBool = not toolBool
                            drawScreen("c")
                        elseif rcl.buttonTab[i]["returnVal"] == "save" then
                            if not fs.isDirectory(path.."/Images/") then fs.makeDirectory(path.."/Images/") end
                            image:saveImage(filename, path.."/Images/"..filename)
                            return true
                        elseif rcl.buttonTab[i]["returnVal"] == "load" then
                            browserBool = not browserBool
                            activeLayer = 1
                            drawScreen("c")
                        elseif rcl.buttonTab[i]["returnVal"] == "layers" then
                            layerBool = not layerBool
                            drawScreen("c")
                            return true
                        elseif rcl.buttonTab[i]["returnVal"] == "animate" then
                            playerBool = not playerBool
                            drawScreen("c")
                            return true
                        end
                        return true
                    end
                end
            end
            return false
        elseif ev == "drag" then
            if rcl.grabbed then
                gpu.setForeground(0xFFFFFF)
                gpu.setBackground(0x000000)
                gpu.fill(rcl.xPos, rcl.yPos, rcl.width, rcl.height, " ")
                rcl:move(clx, cly)
                drawScreen()
                return true
            else
                return false
            end
        elseif ev == "drop" then
            rcl.grabbed = false
        end
        return true
    end
    return false
end

function checkPalette(ev, clx, cly, pl, btn)
    if paletteBool then
        local tBool = false
        if ev == "touch" then
            if clx >= pTab.xPos and clx <= pTab.xPos + (pTab.width - 1) then
                if cly >= pTab.yPos and cly <= pTab.yPos + (pTab.height - 1) then
                    pTab.grabbed = true
                    tBool = true
                else
                    pTab.grabbed = false
                    return false
                end
            else
                pTab.grabbed = false
                return false
            end
            for i = 1, #pTab.buttonTab do
                local buttonStX = pTab.xPos + pTab.buttonTab[i]["xPos"]
                local buttonStY = pTab.yPos + pTab.buttonTab[i]["yPos"]
                local buttonMaX = buttonStX + pTab.buttonTab[i]["width"]
                local buttonMaY = buttonStY + pTab.buttonTab[i]["height"]
                if clx >= buttonStX and clx <= buttonMaX then
                    if cly >= buttonStY and cly <= buttonMaY then
                        if pTab.buttonTab[i]["returnVal"] == "add_palette" then
                            newPalette()
                            activePalette = pTab.pCount
                            drawPalette(activePalette)
                        elseif pTab.buttonTab[i]["returnVal"] == "bk_palette" then
                            if activePalette > 1 then
                                activePalette = activePalette - 1
                            end
                            drawPalette(activePalette)
                        elseif pTab.buttonTab[i]["returnVal"] == "fd_palette" then
                            if activePalette == pTab.pCount then
                                newPalette()
                            end
                            activePalette = activePalette + 1
                            drawPalette(activePalette)
                        elseif pTab.buttonTab[i]["returnVal"] == "fg" then
                            fgBool = not fgBool
                            bgBool = false
                            charBool = false
                            drawPalette(activePalette)
                        elseif pTab.buttonTab[i]["returnVal"] == "bg" then
                            fgBool = false
                            bgBool = not bgBool
                            charBool = false
                            drawPalette(activePalette)
                        elseif pTab.buttonTab[i]["returnVal"] == "char" then
                            fgBool = false
                            bgBool = false
                            charBool = not charBool
                            drawPalette(activePalette)
                        elseif pTab.buttonTab[i]["returnVal"] == "never_mind_this" then
                        else
                            if btn == 0 then
                                if fgBool then
                                    fgLast = fgCur
                                    fgCur = pTab.buttonTab[i]["colour"]
                                    layers.transBool = false
                                    drawScreen()
                                elseif bgBool then
                                    bgLast = bgCur
                                    bgCur = pTab.buttonTab[i]["colour"]
                                    layers.transBool = false
                                    drawScreen()
                                end
                            else
                                colourBool = not colourBool
                                pEntry = pTab.buttonTab[i]["returnVal"]
                                layers.transBool = false
                                drawScreen("c")
                            end
                        end
                    end
                end
            end
            if tBool then return true end
        elseif ev == "drag" then
            if pTab.grabbed then
                gpu.setForeground(0xFFFFFF)
                gpu.setBackground(0x000000)
                gpu.fill(pTab.xPos, pTab.yPos, pTab.width, pTab.height, " ")
                pTab:move(clx, cly)
                drawScreen()
                return true
            else
                return false
            end
        elseif ev == "drop" then
            drawPalette(activePalette)
            pTab.grabbed = false
            return true
        end
    end
    return false
end

function checkRGB(ev, clx, cly, pl, btn)
    if colourBool then
        if clx >= colour.xPos and clx <= colour.xPos + colour.width then
            if cly <= colour.yPos and cly <= colour.yPos + colour.height then
                colour.grabbed = true
            end
        end
        if ev == "touch" then
            for i = 1, #colour.buttonTab do
                local stx = colour.xPos + colour.buttonTab[i]["xPos"]
                local sty = colour.yPos + (colour.buttonTab[i]["yPos"] - 1)
                local max = stx + colour.buttonTab[i]["width"]
                local may = sty + colour.buttonTab[i]["height"]
                if clx >= stx and clx <= max then
                    if cly >= sty and cly <= may then
                        if colour.buttonTab[i]["returnVal"] == "r_plus" then
                            if colour.rVal < 6 then
                                colour.rVal = colour.rVal + 1
                            end
                        elseif colour.buttonTab[i]["returnVal"] == "r_minus" then
                            if colour.rVal > 1 then
                                colour.rVal = colour.rVal - 1
                            end
                        elseif colour.buttonTab[i]["returnVal"] == "g_plus" then
                            if colour.gVal < 6 then
                                colour.gVal = colour.gVal + 1
                            end
                        elseif colour.buttonTab[i]["returnVal"] == "g_minus" then
                            if colour.gVal > 1 then
                                colour.gVal = colour.gVal - 1
                            end
                        elseif colour.buttonTab[i]["returnVal"] == "b_plus" then
                            if colour.bVal < 6 then
                                colour.bVal = colour.bVal + 1
                            end
                        elseif colour.buttonTab[i]["returnVal"] == "b_minus" then
                            if colour.bVal > 1 then
                                colour.bVal = colour.bVal - 1
                            end
                        elseif colour.buttonTab[i]["returnVal"] == "set_colour" then
                            pTab.list[activePalette][pEntry] = tonumber("0x"..vTab[colour.rVal]..vTab[colour.gVal]..vTab[colour.bVal])
                            colourBool = false
                            drawScreen("c")
                        elseif colour.buttonTab[i]["returnVal"] == "exit" then
                            colourBool = false
                            drawScreen("c")
                        end
                        colourChanger()
                        return true
                    end
                end
            end
            return false
        elseif ev == "drag" then
            if colour.grabbed then
                gpu.setForeground(0xFFFFFF)
                gpu.setBackground(0x000000)
                gpu.fill(colour.xPos, colour.yPos, colour.width, colour.height, " ")
                colour:move(clx, cly)
                drawScreen()
                return true
            else
                return false
            end
        elseif ev == "drop" then
            colour.grabbed = false
        end
        return true
    end
    return false
end

function checkToolBox(ev, clx, cly, pl, btn)
    if toolBool then
        if ev == "touch" then
            for i = 1, #tools.buttonTab do
                local stx = tools.xPos + tools.buttonTab[i]["xPos"]
                local sty = tools.yPos + (tools.buttonTab[i]["yPos"] - 1)
                local max = stx + tools.buttonTab[i]["width"]
                local may = sty + tools.buttonTab[i]["height"]
                if clx >= stx and clx <= max then
                    if cly >= sty and cly <= may then
                        if tools.buttonTab[i]["returnVal"] == "brSwitch" then
                            tools.brush["active"] = true
                            tools.line["active"] = false
                            tools.boxTool["active"] = false
                            tools.circle["active"] = false
                        elseif tools.buttonTab[i]["returnVal"] == "lSwitch" then
                            tools.brush["active"] = false
                            tools.line["active"] = true
                            tools.boxTool["active"] = false
                            tools.circle["active"] = false
                        elseif tools.buttonTab[i]["returnVal"] == "bSwitch" then
                            tools.brush["active"] = false
                            tools.line["active"] = false
                            tools.boxTool["active"] = true
                            tools.circle["active"] = false
                        elseif tools.buttonTab[i]["returnVal"] == "cSwitch" then
                            tools.brush["active"] = false
                            tools.line["active"] = false
                            tools.boxTool["active"] = false
                            tools.circle["active"] = true
                        elseif tools.buttonTab[i]["returnVal"] == "brx_minus" then
                            if tools.brush["sizeX"] > 1 then
                                tools.brush["sizeX"] = tools.brush["sizeX"] - 1
                            end
                        elseif tools.buttonTab[i]["returnVal"] == "brx_plus" then
                            tools.brush["sizeX"] = tools.brush["sizeX"] + 1
                        elseif tools.buttonTab[i]["returnVal"] == "bry_minus" then
                            if tools.brush["sizeY"] > 1 then
                                tools.brush["sizeY"] = tools.brush["sizeY"] - 1
                            end
                        elseif tools.buttonTab[i]["returnVal"] == "bry_plus" then
                            tools.brush["sizeY"] = tools.brush["sizeY"] + 1
                        elseif tools.buttonTab[i]["returnVal"] == "rad_minus" then
                            if tools.circle["radius"] > 1 then
                                tools.circle["radius"] = tools.circle["radius"] - 1
                            end
                        elseif tools.buttonTab[i]["returnVal"] == "rad_plus" then
                            tools.circle["radius"] = tools.circle["radius"] + 1
                        elseif tools.buttonTab[i]["returnVal"] == "toggle_filled" then
                            tools.circle["solid"] = not tools.circle["solid"]
                        end
                        tools.grabbed = false
                        drawScreen()
                        return true
                    end
                end
            end
            if clx >= tools.xPos and clx <= tools.xPos + (tools.width - 1) then
                if cly >= tools.yPos and cly <= tools.yPos + (tools.height - 1) then
                    tools.grabbed = true
                    return true
                end
            end
            return false
        elseif ev == "drag" then
            if tools.grabbed then
                gpu.setForeground(0xFFFFFF)
                gpu.setBackground(0x000000)
                gpu.fill(tools.xPos, tools.yPos, tools.width, tools.height, " ")
                tools:move(clx, cly)
                drawScreen()
                return true
            end
        elseif ev == "drop" then
            tools.grabbed = false
            return true
        end
    end
    tools.grabbed = false
    return false
end

function checkFileViewer(ev, clx, cly, pl, btn)
    if browserBool then
        if clx >= browser.xPos and clx <= browser.xPos + browser.width then
            if cly <= browser.yPos and cly <= browser.yPos + browser.height then
                browser.grabbed = true
            end
        end
        if browser.fileViewer ~= nil then
            if ev == "touch" then
                for j = 1, #browser.fileViewer do
                    for k = 1, #browser.fileViewer[j]["list"] do
                        if clx >= browser.xPos + browser.fileViewer[j]["xPos"] and clx <= browser.xPos + #browser.fileViewer[j]["list"][k] then
                            if cly == browser.yPos + (browser.fileViewer[j]["yPos"] + k) then
                                if fs.isDirectory(browser.fileViewer[j]["path"]) then
                                    if string.sub(browser.fileViewer[j]["path"], #browser.fileViewer[j]["path"], #browser.fileViewer[j]["path"]) == "/" then
                                        browser.fileViewer[j]["path"] = string.sub(browser.fileViewer[j]["path"], 1, #browser.fileViewer[j]["path"] - 1)
                                    end
                                end
                                if fs.isDirectory(browser.fileViewer[j]["path"].."/"..browser.fileViewer[j]["list"][k].."/") then
                                    browser.fileViewer[j]["path"] = browser.fileViewer[j]["path"].."/"..browser.fileViewer[j]["list"][k].."/"
                                    browser.fileViewer[j]["list"] = browser:assembleFileTable(browser.fileViewer[j]["path"])
                                    browser.textInputs[1]["text"][1] = browser.fileViewer[j]["path"]
                                    browser.textInputs[1]["cursorX"] = #browser.textInputs[1]["text"][1] + 1
                                    browser:render()
                                    return true
                                else
                                    if btn == 0 then
                                        image = nil
                                        image = screen:newPane(image, width, height)
                                        image:loadImage(filename, browser.fileViewer[j]["path"].."/"..browser.fileViewer[j]["list"][k], 1, 1)
                                        --image:resize(image.imTab[1]["width"], image.imTab[1]["height"])
                                        image:center()
                                        filename = browser.fileViewer[j]["list"][k]
                                        browserBool = false
                                        drawScreen("c")
                                        return true
                                    else
                                        browserBool = false
                                        drawScreen("c")
                                        return false
                                    end
                                end
                            end
                        end
                    end
                end
                for i = 1, #browser.buttonTab do
                    local stx = browser.xPos + browser.buttonTab[i]["xPos"]
                    local sty = browser.yPos + (browser.buttonTab[i]["yPos"] - 1)
                    local max = stx + browser.buttonTab[i]["width"]
                    local may = sty + browser.buttonTab[i]["height"]
                    if clx >= stx and clx <= max then
                        if cly >= sty and cly <= may then
                            if browser.buttonTab[i]["returnVal"] == "navigate_up" then
                                browser.fileViewer[1]["path"] = fs.path(browser.fileViewer[1]["path"])
                                browser.fileViewer[1]["list"] = browser:assembleFileTable(browser.fileViewer[1]["path"])
                                browser.textInputs[1]["text"][1] = browser.fileViewer[1]["path"]
                                browser.textInputs[1]["cursorX"] = #browser.textInputs[1]["text"][1] + 1
                                browser:render()
                            end
                        end
                    end
                end
            elseif ev == "drag" then
                if browser.grabbed then
                    gpu.setForeground(0xFFFFFF)
                    gpu.setBackground(0x000000)
                    gpu.fill(browser.xPos, browser.yPos, browser.width, browser.height, " ")
                    browser:move(clx, cly)
                    drawScreen()
                    return true
                end
            elseif ev == "drop" then
                browser.grabbed = false
                return true
            end
        end
    end
    browser.grabbed = false
    return false
end

function checkLayers(ev, clx, cly, pl, btn)
    if layerBool then
        if ev == "touch" then
            for i = 1, #layers.buttonTab do
                local stx = layers.xPos + layers.buttonTab[i]["xPos"]
                local sty = layers.yPos + (layers.buttonTab[i]["yPos"] - 1)
                local max = stx + layers.buttonTab[i]["width"]
                local may = sty + layers.buttonTab[i]["height"]
                if clx >= stx and clx <= max then
                    if cly >= sty and cly <= may then
                        if layers.buttonTab[i]["returnVal"] == "trans_toggle" then
                            layers.transBool = not layers.transBool
                            if layers.transBool then
                                bgLast = bgCur
                                bgCur = "trans"
                            else
                                bgCur = bgLast
                            end
                        elseif layers.buttonTab[i]["returnVal"] == "page_up" then
                            if layers.lPage < image.imTab[1]["pages"] then
                                layers.lPage = layers.lPage + 1
                            end
                        elseif layers.buttonTab[i]["returnVal"] == "page_down" then
                            if layers.lPage > 1 then
                                layers.lPage = layers.lPage - 1
                            end
                        elseif layers.buttonTab[i]["returnVal"] == "new_layer" then
                            image:newImageLayer(filename)
                        elseif string.sub(layers.buttonTab[i]["returnVal"], 1, 5) == "hide_" then
                            image.imTab[1]["layerData"][tonumber(string.sub(layers.buttonTab[i]["returnVal"], 6, #layers.buttonTab[i]["returnVal"]))]["hidden"] = true
                        elseif string.sub(layers.buttonTab[i]["returnVal"], 1, 5) == "show_" then
                            image.imTab[1]["layerData"][tonumber(string.sub(layers.buttonTab[i]["returnVal"], 6, #layers.buttonTab[i]["returnVal"]))]["hidden"] = false
                        elseif layers.buttonTab[i]["returnVal"] == "no_action" then
                        else
                            activeLayer = layers.buttonTab[i]["returnVal"]
                        end
                        layers.grabbed = false
                        drawScreen("c")
                        return true
                    end
                end
            end
            if clx >= layers.xPos and clx <= layers.xPos + (layers.width - 1) then
                if cly >= layers.yPos and cly <= layers.yPos + (layers.height - 1) then
                    layers.grabbed = true
                    return true
                end
            end
            return false
        elseif ev == "drag" then
            if layers.grabbed then
                gpu.setForeground(0xFFFFFF)
                gpu.setBackground(0x000000)
                gpu.fill(layers.xPos, layers.yPos, layers.width, layers.height, " ")
                layers:move(clx, cly)
                drawScreen()
                return true
            end
        elseif ev == "drop" then
            layers.grabbed = false
            return true
        end
    end
    layers.grabbed = false
    return false
end

function checkPlayer(ev, clx, cly, pl, btn)
    if playerBool then
        if ev == "touch" then
            for i = 1, #player.buttonTab do
                local stx = player.xPos + player.buttonTab[i]["xPos"]
                local sty = player.yPos + (player.buttonTab[i]["yPos"] - 1)
                local max = stx + player.buttonTab[i]["width"]
                local may = sty + player.buttonTab[i]["height"]
                if clx >= stx and clx <= max then
                    if cly >= sty and cly <= may then
                        if player.buttonTab[i]["returnVal"] == "play" then
                            playVideo()
                        elseif player.buttonTab[i]["returnVal"] == "loop" then
                            player.loop = not player.loop
                        end
                        player.grabbed = false
                        drawScreen("c")
                        return true
                    end
                end
            end
            if clx >= player.xPos and clx <= player.xPos + (player.width - 1) then
                if cly >= player.yPos and cly <= player.yPos + (player.height - 1) then
                    player.grabbed = true
                    return true
                end
            end
            return false
        elseif ev == "drag" then
            if player.grabbed then
                gpu.setForeground(0xFFFFFF)
                gpu.setBackground(0x000000)
                gpu.fill(player.xPos, player.yPos, player.width, player.height, " ")
                player:move(clx, cly)
                drawScreen()
                return true
            end
        elseif ev == "drop" then
            player.grabbed = false
            return true
        end
    end
    player.grabbed = false
    return false
end

function run()
    ev, p1, p2, p3, p4, p5 = event.pull(.1, _, ev, p1, p2, p3, p4, p5)
    if ev == "key_up" then
        return true
    elseif ev == "key_down" then
        running = false
        return false
    elseif ev ~= nil then
        if checkRCL(ev, p2, p3, p5, p4) then return end
        rcl.grabbed = false
        if checkRGB(ev, p2, p3, p5, p4) then return end
        colour.grabbed = false
        if checkPalette(ev, p2, p3, p5, p4) then return end
        pTab.grabbed = false
        if checkFileViewer(ev, p2, p3, p5, p4) then return end
        browser.grabbed = false
        if checkToolBox(ev, p2, p3, p5, p4) then return end
        tools.grabbed = false
        if checkLayers(ev, p2, p3, p5, p4) then return end
        layers.grabbed = false
        if checkPlayer(ev, p2, p3, p5, p4) then return end
        player.grabbed = false
        if checkImage(ev, p2, p3, p5, p4) then return end
        image.running = false
        if p4 == 1 then
            menuBool = not menuBool
            drawScreen("c")
        end
    end
end

--PROGRAM START--

rClickMenuSetup()
paletteSetup()
colourSetup()
browser = fileBrowser(0x00CCCC, "Load File")
toolBox()
layerTool()
initPlayer()
if fs.exists(path.."/Images/"..filename) then
    image = screen:newPane(image, width, height)
    image:loadImage(filename, path.."/Images/"..filename, 1, 1)
    image:center()
else
    image = newImage(width, height)
end
drawScreen("c")
running = true
while running do
    run()
end
gpu.setForeground(0xFFFFFF)
gpu.setBackground(0x000000)
