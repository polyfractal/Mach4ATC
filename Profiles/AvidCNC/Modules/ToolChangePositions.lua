package.path = "C:\\Mach4Hobby\\Modules\\?.lua;"

if(package.loaded.mcAutoTool == nil) then
    mcAutoTool = require "mcAutoTool"
end

local ATC = {}
local inst = mc.mcGetInstance()
local CSVPath = "C:\\Mach4Hobby\\Profiles\\AvidCNC\\Modules\\ToolChangePositions.csv"

local ToolNum = 0;
io.input(io.open(CSVPath,"r"))

-- Load tool table and offsets
for line in io.lines(CSVPath) do
    local tkz = wx.wxStringTokenizer(line, ",");
    ATC[ToolNum] = {}-- make a blank table in the positions table to hold the tool data
    local token = tkz:GetNextToken();
    ATC[ToolNum] ["Tool_Number"] = token;
    ATC[ToolNum] ["Name"] = tkz:GetNextToken();
    ATC[ToolNum] ["X_Position"] = tkz:GetNextToken();
    ATC[ToolNum] ["Y_Position"] = tkz:GetNextToken();
    ATC[ToolNum] ["Z_Position"] = tkz:GetNextToken();
    ATC["Max"] = ToolNum
    ToolNum = ToolNum + 1;
end

io.close()


-- Function to fetch the details about SelectedToolNum, or return nil if doesn't exist
function ATC.GetToolData(SelectedToolNum)
    local MaxToolNum = ATC["Max"]
    if (SelectedToolNum <= MaxToolNum) and (SelectedToolNum > 0) then
        return ATC[SelectedToolNum]
    else
        return nil
    end
end

-- Function to probe the current tool
-- Uses the AutoToolSet module that ships with Mach4
function ATC.probeLength()

    ------ Get current state ------
    local CurFeed = mc.mcCntlGetPoundVar(inst, 2134)
    local CurFeedMode = mc.mcCntlGetPoundVar(inst, 4001)
    local CurAbsMode = mc.mcCntlGetPoundVar(inst, 4003)

    -- If we don't have a height for this tool, guess 3" because nothing should be longer
    local length = mc.mcToolGetData(inst, mc.MTOOL_MILL_HEIGHT, mc.mcToolGetCurrent(inst));
    if (length == nil or length == 0) then
        length = 3
    end

    -- Temporary: override and set to 3in.  Guessing based on old tool length seems dangerous,
    -- probably better to prompt user for guess of new tool instead
    mcAutoTool.AutoToolSet(3)

    ------ Reset state ------
    mc.mcCntlSetPoundVar(inst, 2134, CurFeed)
    mc.mcCntlSetPoundVar(inst, 4001, CurFeedMode)
    mc.mcCntlSetPoundVar(inst, 4003, CurAbsMode)

end

-- Function to change from CurrentTool to SelectedTool.  If `probe` is true it will
-- also probe the height offset.
function ATC.m6(CurrentTool, SelectedTool, probe)
    CurrentTool = tonumber(CurrentTool)
    SelectedTool = tonumber(SelectedTool)

    if (SelectedTool == CurrentTool) then
        mc.mcCntlSetLastError(inst, "Next tool = Current tool")
        do return end
    end

    ------ Get current state ------
    local CurFeed = mc.mcCntlGetPoundVar(inst, 2134)
    local CurFeedMode = mc.mcCntlGetPoundVar(inst, 4001)
    local CurAbsMode = mc.mcCntlGetPoundVar(inst, 4003)

    local Num1
    local XPos1
    local YPos1
    local ZPos1
    local Num2
    local XPos2
    local YPos2
    local ZPos2

    ------ Get position data for current tool ------
    local ToolData = ATC.GetToolData(CurrentTool)
    if (ToolData ~= nil) then
        Num1 = ToolData.Tool_Number
        XPos1 = ToolData.X_Position
        YPos1 = ToolData.Y_Position
        ZPos1 = ToolData.Z_Position
    else
        mc.mcCntlEStop(inst)
        mc.mcCntlSetLastError(inst, "ERROR: Tool number out of range!")
        do return end
    end

    ------ Get position data for next tool ------
    ToolData = ATC.GetToolData(SelectedTool)
    if (ToolData ~= nil) then
        Num2 = ToolData.Tool_Number
        XPos2 = ToolData.X_Position
        YPos2 = ToolData.Y_Position
        ZPos2 = ToolData.Z_Position
    else
        mc.mcCntlEStop(inst)
        mc.mcCntlSetLastError(inst, "ERROR: Tool number out of range!")
        do return end
    end

    mc.mcCntlSetLastError(inst, string.format("Moving to Tool %.1f [%.4f, %.4f, %.4f]", CurrentTool, XPos1, YPos1, ZPos1))
    ------ Move to current tool change position ------
    local GCode = ""
    GCode = GCode .. "G00 G90 G53 Z-0.5\n"
    GCode = GCode .. string.format("G00 G90 G53 X%.4f Y%.4f\n", XPos1, YPos1)
    GCode = GCode .. string.format("G00 G90 G53 Z%.4f\n", ZPos1 + 1.0)
    GCode = GCode .. string.format("G01 G90 G53 Z%.4f F15.0\n", ZPos1)
    mc.mcCntlGcodeExecuteWait(inst, GCode)

    ------ Release drawbar ------
    local DrawBarOut = mc.OSIG_COOLANTON
    local hsig = mc.mcSignalGetHandle(inst, DrawBarOut)
    mc.mcSignalSetState(hsig, 1)
    mc.mcCntlGcodeExecuteWait(inst, "G4 P1500\n")

    ------ Move to next tool change position ------\
    mc.mcCntlSetLastError(inst, string.format("Moving to Tool %.1f [%.4f, %.4f, %.4f]", SelectedTool, XPos2, YPos2, ZPos2))
    GCode = ""
    GCode = GCode .. string.format("G01 G90 G53 Z%.4f\n F15.0", ZPos2 + 1.0)
    GCode = GCode .. "G00 G90 G53 Z-2.5\n"
    GCode = GCode .. string.format("G00 G90 G53 X%.4f Y%.4f\n", XPos2, YPos2)
    GCode = GCode .. string.format("G00 G90 G53 Z%.4f\n", ZPos2 + 1.0)
    GCode = GCode .. string.format("G01 G90 G53 Z%.4f F15.0\n", ZPos2)
    mc.mcCntlGcodeExecuteWait(inst, GCode)

    ------ Clamp drawbar ------
    mc.mcSignalSetState(hsig, 0)
    mc.mcCntlGcodeExecuteWait(inst, "G4 P1500\n")

    ------ Move Z to home position ------
    mc.mcCntlGcodeExecuteWait(inst, "G00 G90 G53 Z-0.5\n")

    ------ Reset state ------
    mc.mcCntlSetPoundVar(inst, 2134, CurFeed)
    mc.mcCntlSetPoundVar(inst, 4001, CurFeedMode)
    mc.mcCntlSetPoundVar(inst, 4003, CurAbsMode)

    ------ Set new tool ------
    mc.mcToolSetCurrent(inst, SelectedTool)
    mc.mcCntlSetLastError(inst, string.format("Tool change - Tool: %.0f", SelectedTool))

    if (probe == true) then
        ATC.probeLength()
    end

end

-- Function to manually replace CurrentTool with SelectedTool.  Will perform an M6
-- if CurrentTool != SelectedTool, then move to the front of the machine and prompt
-- the user to change the tool.  After changing it will re-probe the offset.
function ATC.replace(CurrentTool, SelectedTool)

    CurrentTool = tonumber(CurrentTool)
    SelectedTool = tonumber(SelectedTool)

    if (CurrentTool ~= SelectedTool) then
        ATC.m6(CurrentTool, SelectedTool, false)
    end

    ------ Get current state ------
    local CurFeed = mc.mcCntlGetPoundVar(inst, 2134)
    local CurFeedMode = mc.mcCntlGetPoundVar(inst, 4001)
    local CurAbsMode = mc.mcCntlGetPoundVar(inst, 4003)

    local Num1
    local XPos1
    local YPos1
    local ZPos1

    CurrentTool = SelectedTool

    ------ Get position data for current tool ------
    local ToolData = ATC.GetToolData(CurrentTool)
    if (ToolData ~= nil) then
        Num1 = ToolData.Tool_Number
        XPos1 = ToolData.X_Position
        YPos1 = ToolData.Y_Position
        ZPos1 = ToolData.Z_Position
    else
        mc.mcCntlEStop(inst)
        mc.mcCntlSetLastError(inst, "ERROR: Tool number out of range!")
        do return end
    end


    mc.mcCntlSetLastError(inst, string.format("Moving to Tool Change Point [%.4f, %.4f, %.4f]", CurrentTool, 12.0, 1.0, -0.5))
    ------ Move to current tool change position ------
    local GCode = ""
    GCode = GCode .. "G00 G90 G53 Z-0.5\n"
    GCode = GCode .. string.format("G00 G90 G53 X%.4f Y%.4f\n", 12.0, 1.0)
    mc.mcCntlGcodeExecuteWait(inst, GCode)

    wx.wxMessageBox("Release drawbar?")

    ------ Release drawbar ------
    local DrawBarOut = mc.OSIG_COOLANTON
    local hsig = mc.mcSignalGetHandle(inst, DrawBarOut)
    mc.mcSignalSetState(hsig, 1)

    wx.wxMessageBox("Clamp drawbar?")

    mc.mcSignalSetState(hsig, 0)

    ------ Reset state ------
    mc.mcCntlSetPoundVar(inst, 2134, CurFeed)
    mc.mcCntlSetPoundVar(inst, 4001, CurFeedMode)
    mc.mcCntlSetPoundVar(inst, 4003, CurAbsMode)

    ------ Set new tool ------
    mc.mcToolSetCurrent(inst, SelectedTool)
    mc.mcCntlSetLastError(inst, string.format("Tool replaced - Tool: %.0f", SelectedTool))

    ATC.probeLength()
end


return ATC

