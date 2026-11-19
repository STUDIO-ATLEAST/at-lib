local isShowing = false
local currentText

---@param textOrKey string
---@param optionsOrLabel? table|string
function lib.showTextUI(textOrKey, optionsOrLabel)
    if type(textOrKey) ~= 'string' or textOrKey == '' then return end

    local key, label, position
    if type(optionsOrLabel) == 'string' then
        key = textOrKey
        label = optionsOrLabel
    else
        label = textOrKey
        position = type(optionsOrLabel) == 'table' and optionsOrLabel.position or nil
    end

    if currentText == textOrKey and isShowing then return end
    isShowing = true
    currentText = textOrKey

    SendNUIMessage({
        action = 'SHOW_TEXTUI',
        data = {
            key = key,
            label = label,
            position = position,
        },
    })
end

function lib.hideTextUI()
    if not isShowing then return end
    isShowing = false
    currentText = nil

    SendNUIMessage({
        action = 'HIDE_TEXTUI',
        data = true,
    })
end

---@return boolean, string?
function lib.isTextUIOpen()
    return isShowing, currentText
end

exports('showTextUI', lib.showTextUI)
exports('hideTextUI', lib.hideTextUI)
exports('isTextUIOpen', lib.isTextUIOpen)
