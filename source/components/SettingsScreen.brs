Sub init()
    ' Find UI nodes
    m.LoginTabBtn = m.top.findNode("LoginTabBtn")
    m.FavoritesTabBtn = m.top.findNode("FavoritesTabBtn")
    m.LoginTabContent = m.top.findNode("LoginTabContent")
    m.FavoritesTabContent = m.top.findNode("FavoritesTabContent")
    m.EmailInput = m.top.findNode("EmailInput")
    m.PasswordInput = m.top.findNode("PasswordInput")
    m.SaveLoginBtn = m.top.findNode("SaveLoginBtn")
    m.StatusLabel = m.top.findNode("StatusLabel")
    m.LogoutBtn = m.top.findNode("LogoutBtn")
    m.BackBtn = m.top.findNode("BackBtn")

    ' Initialize tab state (0 = Login & Session, 1 = Favorites)
    m.activeTab = 0

    ' Load persisted credentials and auth state
    loadAuthData()
    updateLoginStatusUI()

    ' Set initial focus on Email input
    m.EmailInput.setFocus(true)

    ' Observe button presses
    m.LoginTabBtn.observeField("pressed", "onLoginTabPressed")
    m.FavoritesTabBtn.observeField("pressed", "onFavoritesTabPressed")
    m.SaveLoginBtn.observeField("pressed", "onSaveLoginPressed")
    m.LogoutBtn.observeField("pressed", "onLogoutPressed")
    m.BackBtn.observeField("pressed", "onBackPressed")

    ' Observe auth state changes from global node
    m.global.observeField("loggedIn", "onAuthStateChanged")
End Sub

Function loadAuthData() As Void
    registry = CreateObject("roRegistrySection", "Auth")

    if registry.Exists("email") then
        m.EmailInput.text = registry.Read("email")
    end if

    ' Note: password is NOT auto-filled for security reasons
    ' User must re-enter password on each login attempt
End Function

Function updateLoginStatusUI() As Void
    loggedIn = m.global.loggedIn

    if loggedIn = true then
        ' Show logout button, hide save/login button
        m.LogoutBtn.visible = true
        m.SaveLoginBtn.visible = false
        m.FavoritesTabBtn.visible = true
    else
        ' Hide logout button, show save/login button
        m.LogoutBtn.visible = false
        m.SaveLoginBtn.visible = true
        m.FavoritesTabBtn.visible = false
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
        m.LoginTabContent.visible = true
        m.FavoritesTabContent.visible = false
        m.LoginTabBtn.setFocus(true)
    else if tabIndex = 1 then ' Favorites tab
        m.LoginTabContent.visible = false
        m.FavoritesTabContent.visible = true
        m.FavoritesTabBtn.setFocus(true)
    end if
End Function

Function onLoginTabPressed() As Void
    switchToTab(0)
End Function

Function onFavoritesTabPressed() As Void
    switchToTab(1)
End Function

Function onSaveLoginPressed() As Void
    email = m.EmailInput.text.Trim()
    password = m.PasswordInput.text

    if email = "" or password = "" then
        showStatus("Error: Please enter both email and password.", false)
        return
    end if

    ' TODO: Trigger login flow via HttpManager
    ' For now, just save credentials to registry as a test
    saveAuthData(email, password)
    showStatus("Credentials saved. Login flow coming soon...", true)
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

    m.EmailInput.text = ""
    m.PasswordInput.text = ""
End Function

Function showStatus(message as String, success as Boolean) As Void
    m.StatusLabel.text = message
    m.StatusLabel.visible = true

    ' Green for success, red for error
    if success then
        m.StatusLabel.color = "0x00AA00"
    else
        m.StatusLabel.color = "0xFF3333"
    end if
End Function
