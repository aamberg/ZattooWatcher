Sub init()
    ' Create HttpManager instance for login flow
    m.httpManager = createObject("roSGNode", "HttpManager")
    
    ' Find UI nodes
    m.emailFieldGroup = m.top.findNode("emailFieldGroup")
    m.passwordFieldGroup = m.top.findNode("passwordFieldGroup")
    m.loginButton = m.top.findNode("loginButton")
    
    m.emailText = m.top.findNode("emailText")
    m.passwordText = m.top.findNode("passwordText")
    m.emailBorder = m.top.findNode("emailBorder")
    m.passwordBorder = m.top.findNode("passwordBorder")
    m.buttonBg = m.top.findNode("buttonBg")
    m.buttonText = m.top.findNode("buttonText")
    
    m.dialogPane = m.top.findNode("dialogPane")
    
    m.emailValue = ""
    m.passwordValue = ""
    
    ' Fokus-Index: 0 = Email, 1 = Password, 2 = Login-Button
    m.focusIndex = 0
    updateFocus()

    ' Initialize tab state (0 = Login & Session, 1 = Favorites)
    m.activeTab = 0

    ' Load persisted credentials and auth state
    loadAuthData()
    updateLoginStatusUI()


    ' Observe button presses
    'm.LoginTabBtn.observeField("pressed", "onLoginTabPressed")
    'm.FavoritesTabBtn.observeField("pressed", "onFavoritesTabPressed")
    'm.LogoutBtn.observeField("pressed", "onLogoutPressed")
    'm.BackBtn.observeField("pressed", "onBackPressed")

    ' Observe auth state changes from global node
    m.global.observeField("loggedIn", "onAuthStateChanged")
End Sub

sub updateFocus()
    ' Reset Borders & Buttons
    m.emailBorder.color = "#3A3F47"
    m.passwordBorder.color = "#3A3F47"
    m.buttonBg.color = "#FFFFFF"
    m.buttonText.color = "#2B2B2B"
    
    if m.focusIndex = 0
        m.emailBorder.color = "#FFFFFF"
    else if m.focusIndex = 1
        m.passwordBorder.color = "#FFFFFF"
    else if m.focusIndex = 2
        m.buttonBg.color = "#A0A5AE"
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    handled = false
    
    if press
        if key = "down"
            if m.focusIndex < 2
                m.focusIndex = m.focusIndex + 1
                updateFocus()
                handled = true
            end if
        else if key = "up"
            if m.focusIndex > 0
                m.focusIndex = m.focusIndex - 1
                updateFocus()
                handled = true
            end if
        else if key = "OK"
            if m.focusIndex = 0
                openTextInputDialog("Email eingeben", m.emailValue, "email")
                handled = true
            else if m.focusIndex = 1
                openTextInputDialog("Passwort eingeben", m.passwordValue, "password")
                handled = true
            else if m.focusIndex = 2
                print "> SettingsScreen: login button pressed"
                triggerLoginFlow()
                handled = true
            end if
        end if
    end if
    
    return handled
end function

sub openTextInputDialog(title as String, currentText as String, mode as String)
    dialog = createObject("roSGNode", "Dialog")
    dialog.title = title
    
    ' Wir fügen ein Eingabefeld oder direkt Buttons hinzu
    dialog.optionsDialog = true
    
    ' Nutzen wir standardmäßig ein MessageDialog mit Buttons für den Komfort, 
    ' oder übergeben einen Standard-PinPadDialog falls es numerisch ist.
    ' Für einen universellen Textdialog ist der Standard KeyboardDialog ohne Button-Zwang so zu bedienen:
    kbDialog = createObject("roSGNode", "KeyboardDialog")
    kbDialog.title = title
    kbDialog.text = currentText
    
    ' Roku KeyboardDialog hat standardmäßig Buttons wie [OK] und [Cancel] 
    ' in der Dialog-Struktur, diese werden über addButtons gesteuert:
    kbDialog.buttons = ["OK", "Abbrechen"]
    
    m.activeInputMode = mode
    m.dialogPane.appendChild(kbDialog)
    
    ' Hier lauschen wir nun korrekt auf den Button-Index statt auf Enter
    kbDialog.observeField("buttonSelected", "onDialogButtonSelected")
end sub

sub onDialogButtonSelected(event as Object)
    dialog = event.getRoSGNode()
    buttonIndex = dialog.buttonSelected
    print "Keyboard closed. Button index: "; buttonIndex; ", Text: "; dialog.text
    ' Button 0 ist "OK", Button 1 ist "Abbrechen"
    if buttonIndex = 0
        inputText = dialog.text
        if m.activeInputMode = "email"
            m.emailValue = inputText
            if inputText <> ""
                m.emailText.text = inputText
                m.emailText.color = "#FFFFFF"
            else
                m.emailText.text = "email@example.com"
                m.emailText.color = "#70757E"
            end if
            m.focusIndex = 1
        else if m.activeInputMode = "password"
            m.passwordValue = inputText
            if inputText <> ""
                masked = ""
                for i = 1 to inputText.len()
                    masked = masked + "•"
                end for
                m.passwordText.text = masked
                m.passwordText.color = "#FFFFFF"
            else
                m.passwordText.text = "••••••••"
                m.passwordText.color = "#70757E"
            end if
            m.focusIndex = 2
        end if
    end if
    
    m.dialogPane.removeChild(dialog)
    m.top.setFocus(true)
    updateFocus()
end sub

Function loadAuthData() As Void
    registry = CreateObject("roRegistrySection", "Auth")

    if registry.Exists("email") then
        m.emailValue = registry.Read("email")
        m.emailText.text = m.emailValue
        m.emailText.color = "#FFFFFF"
    end if

    ' Note: password is NOT auto-filled for security reasons
    ' User must re-enter password on each login attempt
End Function

Function updateLoginStatusUI() As Void
    loggedIn = m.global.loggedIn

    if loggedIn = true then
        ' Show logout button, hide save/login button
        'm.LogoutBtn.visible = true
        m.loginButton.visible = false
        'm.FavoritesTabBtn.visible = true
    else
        ' Hide logout button, show save/login button
        'm.LogoutBtn.visible = false
        m.loginButton.visible = true
        'm.FavoritesTabBtn.visible = false
    end if

    ' Ensure Login tab is active when not logged in (Favorites unavailable)
    if loggedIn = false then
        switchToTab(0)
    end if
End Function

Function onAuthStateChanged() As Void
    updateLoginStatusUI()
End Function

Function switchToTab(tabIndex as Integer) As Void
    m.activeTab = tabIndex

    if tabIndex = 0 then ' Login & Session tab
        'm.LoginTabContent.visible = true
        'm.FavoritesTabContent.visible = false
        'm.LoginTabBtn.setFocus(true)
    else if tabIndex = 1 then ' Favorites tab
        'm.LoginTabContent.visible = false
        'm.FavoritesTabContent.visible = true
        'm.FavoritesTabBtn.setFocus(true)
    end if
End Function

Function onLoginTabPressed() As Void
    switchToTab(0)
End Function

Function onFavoritesTabPressed() As Void
    switchToTab(1)
End Function

'=============================================================================
' Trigger the multi-step login flow via HttpManager
'=============================================================================

Function triggerLoginFlow() As Void
    email = m.emailValue.Trim()
    password = m.passwordValue

    if email = "" or password = "" then
        showStatus("Error: Please enter both email and password.", false)
        return
    end if

    print "> SettingsScreen: starting login flow for email: " + email

    ' Call HttpManager.performLogin() with credentials
    result = m.httpManager.performLogin(email, password)

    if result.success then
        print "> SettingsScreen: login successful"
        saveAuthData(email, password)
        m.global.loggedIn = true
        showStatus("Login successful.", true)
        updateLoginStatusUI()
    else
        print "> SettingsScreen: login failed - " + result.error
        if type(result.detail) <> "" and result.detail <> invalid then
            detailError = result.detail.error or "Unknown error"
            print "> SettingsScreen: detail error - " + detailError
        end if
        showStatus("Login failed. Please check your credentials.", false)
    end if
End Function

Function onSaveLoginPressed() As Void
    triggerLoginFlow()
End Function

Function onLogoutPressed() As Void
    clearAuthData()
    m.global.loggedIn = false
    updateLoginStatusUI()
    showStatus("Logged out successfully.", true)
End Function

Function onBackPressed() As Void
    m.top.browseTo("WelcomeScene")
End Function

Function saveAuthData(email as String, password as String) As Void
    registry = CreateObject("roRegistrySection", "Auth")
    registry.Write("email", email)
    registry.Write("password", password)
    registry.Flush()
End Function

Function clearAuthData() As Void
    registry = CreateObject("roRegistrySection", "Auth")
    if registry.Exists("email") then
        registry.Delete("email")
    end if
    if registry.Exists("password") then
        registry.Delete("password")
    end if
    registry.Flush()

    m.emailValue = ""
    m.passwordValue = ""
    m.emailText.text = "email@example.com"
    m.emailText.color = "#70757E"
    m.passwordText.text = "••••••••"
    m.passwordText.color = "#70757E"
End Function

Function showStatus(message as String, success as Boolean) As Void
    'm.StatusLabel.text = message
    'm.StatusLabel.visible = true

    ' Green for success, red for error
    if success then
        'm.StatusLabel.color = "0x00AA00"
    else
        'm.StatusLabel.color = "0xFF3333"
    end if
End Function
