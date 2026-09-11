if frmRegView == nil then

    regLabels  = {}
    lastValues = {}
    bpAddress  = nil
    uiIs64     = nil
    orderMode  = "debug"

    COLOR_RED   = 0x000000FF
    COLOR_GREEN = 0x00008000

    ORDER_DEBUG_64 = {"RAX","RBX","RCX","RDX","RSI","RDI","RBP","RSP",
                      "R8","R9","R10","R11","R12","R13","R14","R15","RIP"}
    ORDER_CPU_64   = {"RAX","RCX","RDX","RBX","RSP","RBP","RSI","RDI",
                      "R8","R9","R10","R11","R12","R13","R14","R15","RIP"}
    ORDER_DEBUG_32 = {"EAX","EBX","ECX","EDX","ESI","EDI","EBP","ESP","EIP"}
    ORDER_CPU_32   = {"EAX","ECX","EDX","EBX","ESP","EBP","ESI","EDI","EIP"}

    function getCurrentOrder()
        if uiIs64 then
            return (orderMode == "cpu") and ORDER_CPU_64 or ORDER_DEBUG_64
        else
            return (orderMode == "cpu") and ORDER_CPU_32 or ORDER_DEBUG_32
        end
    end

    function removeRecordedBreakpoint()
        if bpAddress == nil then
            return false, "当前没有记录断点"
        end
        local ok, err = pcall(function()
            debug_removeBreakpoint(bpAddress)
        end)
        if ok then
            return true
        else
            return false, tostring(err)
        end
    end

    function readRegisters()
        local r = {}
        if targetIs64Bit() then
            r.RAX=RAX; r.RBX=RBX; r.RCX=RCX; r.RDX=RDX
            r.RSI=RSI; r.RDI=RDI; r.RBP=RBP; r.RSP=RSP
            r.R8=R8;   r.R9=R9;   r.R10=R10; r.R11=R11
            r.R12=R12; r.R13=R13; r.R14=R14; r.R15=R15
            r.RIP=RIP
        else
            r.EAX=EAX; r.EBX=EBX; r.ECX=ECX; r.EDX=EDX
            r.ESI=ESI; r.EDI=EDI; r.EBP=EBP; r.ESP=ESP
            r.EIP=EIP
        end
        return r
    end

    function refreshRegs()
        if frmRegView == nil then return end
        local regs = readRegisters()

        for name, lbl in pairs(regLabels) do
            local v = regs[name]
            if v ~= nil then
                local text
                if uiIs64 then
                    text = string.format("%s = %016X", name, v)
                else
                    text = string.format("%s = %08X", name, v)
                end
                lbl.Caption = text

                if lastValues[name] ~= nil and lastValues[name] ~= v then
                    lbl.Font.Color = COLOR_RED
                else
                    lbl.Font.Color = COLOR_GREEN
                end

                lastValues[name] = v
            end
        end
    end

    function onBreakpoint()
        refreshRegs()
        return 0
    end

    function updateBpUI()
        if frmRegView == nil then return end
        if bpAddress ~= nil then
            btnSet.Caption     = "移除断点"
            frmRegView.Caption = string.format("寄存器 - 断点 @ %X", bpAddress)
            lblStatus.Caption  = string.format("当前断点 @ %X", bpAddress)
        else
            btnSet.Caption     = "设置断点"
            frmRegView.Caption = "寄存器 - 未设断点"
            lblStatus.Caption  = "未设置断点"
        end
    end

    function rebuildRegRows()
        for _, lbl in pairs(regLabels) do
            lbl.Destroy()
        end
        regLabels  = {}
        lastValues = {}

        uiIs64 = targetIs64Bit()
        local order = getCurrentOrder()

        local startY = 116
        for i, name in ipairs(order) do
            local lbl = createLabel(frmRegView)
            lbl.Caption = name .. " = --------"
            lbl.Left = 10
            lbl.Top = startY + (i - 1) * 24
            lbl.Width = 250
            lbl.Font.Style = '[fsBold]'
            lbl.Font.Color = COLOR_GREEN
            regLabels[name] = lbl
        end

        frmRegView.Height = startY + #order * 24 + 60
        updateBpUI()
    end

    frmRegView = createForm()
    frmRegView.Width = 280
    frmRegView.Height = 620
    frmRegView.Position = poScreenCenter
    frmRegView.BorderStyle = 'bsSizeable'
    frmRegView.BorderIcons = '[biSystemMenu,biMinimize]'

    local lblAddr = createLabel(frmRegView)
    lblAddr.Caption = "地址:"
    lblAddr.Left = 10; lblAddr.Top = 10; lblAddr.Width = 40

    edtAddr = createEdit(frmRegView)
    edtAddr.Left = 50; edtAddr.Top = 8; edtAddr.Width = 210
    edtAddr.Text = ""

    btnSet = createButton(frmRegView)
    btnSet.Caption = "设置断点"
    btnSet.Left = 10; btnSet.Top = 38; btnSet.Width = 250
    btnSet.Height = 28

    lblStatus = createLabel(frmRegView)
    lblStatus.Caption = "未设置断点"
    lblStatus.Left = 10; lblStatus.Top = 72; lblStatus.Width = 250

    local lblOrder = createLabel(frmRegView)
    lblOrder.Caption = "顺序:"
    lblOrder.Left = 10; lblOrder.Top = 92; lblOrder.Width = 40

    cboOrder = createComboBox(frmRegView)
    cboOrder.Left = 50; cboOrder.Top = 90; cboOrder.Width = 210
    cboOrder.Style = 'csDropDownList'
    cboOrder.Items.add("调试器顺序")
    cboOrder.Items.add("CPU 编码顺序")
    cboOrder.ItemIndex = 0

    cboOrder.OnChange = function(sender)
        orderMode = (cboOrder.ItemIndex == 1) and "cpu" or "debug"
        rebuildRegRows()
    end

    rebuildRegRows()

    btnSet.OnClick = function()
        if bpAddress ~= nil then
            local addr = bpAddress
            local ok, err = removeRecordedBreakpoint()

            bpAddress = nil
            lastValues = {}
            updateBpUI()

            if ok then
                lblStatus.Caption = string.format("已移除断点 @ %X", addr)
            else
                lblStatus.Caption = "移除失败: " .. err
            end
            return
        end

        local addrText = edtAddr.Text
        addrText = addrText:match("^%s*(.-)%s*$")

        if addrText == "" then
            lblStatus.Caption = "地址为空，已跳过"
            return
        end

        if targetIs64Bit() ~= uiIs64 then
            rebuildRegRows()
        end

        local ok, addr = pcall(getAddress, addrText)
        if not ok or type(addr) ~= "number" or addr == 0 then
            lblStatus.Caption = "此地址:" .. addrText .. "无效"
            return
        end

        if bpAddress ~= nil then
            removeRecordedBreakpoint()
            bpAddress = nil
        end

        lastValues = {}

        local ok2, err = pcall(function()
            debug_setBreakpoint(addr, 1, bptExecute, bpmDebugRegister, onBreakpoint)
        end)

        if ok2 then
            bpAddress = addr
            updateBpUI()
        else
            lblStatus.Caption = "设置失败: " .. tostring(err)
        end
    end

    frmRegView.OnClose = function(sender)
        frmRegView = nil
        return caFree
    end

    frmRegView:show()
end
