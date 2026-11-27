Sub init()
    ' Create HttpManager instance for login flow and channel fetching
    m.httpManager = createObject("roSGNode", "HttpManager")
    
    ' Find UI nodes - Login tab content
    m.LoginTabContent = m.top.findNode("LoginTabContent")
    m.emailFieldGroup = m.top.findNode("emailFieldGroup")
    m.passwordFieldGroup = m.top.findNode("passwordFieldGroup")
    m.loginButton = m.top.findNode("loginButton")
    m.logoutButton = m.top.findNode("logoutButton")
    m.statusLabel = m.top.findNode("statusLabel")
    
    m.emailText = m.top.findNode("emailText")
    m.passwordText = m.top.findNode("passwordText")
    m.emailBorder = m.top.findNode("emailBorder")
    m.passwordBorder = m.top.findNode("passwordBorder")
    m.buttonBg = m.top.findNode("buttonBg")
    m.buttonText = m.top.findNode("buttonText")
    
    ' Find UI nodes - Favorites tab content
    m.FavoritesTabContent = m.top.findNode("FavoritesTabContent")
    m.favoritesStatusLabel = m.top.findNode("favoritesStatusLabel")
    m.channelList = m.top.findNode("channelList")
    m.channelListContent = m.top.findNode("channelListContent")
    
    ' Find UI nodes - Tab indicators and buttons
    m.LoginTabBtn = m.top.findNode("LoginTabBtn")
    m.FavoritesTabBtn = m.top.findNode("FavoritesTabBtn")
    m.LoginTabIndicator = m.top.findNode("LoginTabIndicator")
    m.FavoritesTabIndicator = m.top.findNode("FavoritesTabIndicator")
    
    m.BackBtn = m.top.findNode("BackBtn")
    m.dialogPane = m.top.findNode("dialogPane")
    
    m.emailValue = ""
    m.passwordValue = ""
    
    ' Fokus-Index: 0 = Email, 1 = Password, 2 = Login/Logout Button
    m.focusIndex = 0
    updateFocus()

    ' Initialize tab state (0 = Login & Session, 1 = Favorites)
    m.activeTab = 0
    
    ' Channel list and favorites data
    m.channels = []
    m.checkIdToCid = []
    m.favorites = {}
    
    ' Load persisted credentials and auth state
    loadAuthData()
    updateLoginStatusUI()

    ' Observe button presses for tab switching
    m.LoginTabBtn.observeField("pressed", "onLoginTabPressed")
    m.FavoritesTabBtn.observeField("pressed", "onFavoritesTabPressed")
    m.BackBtn.observeField("pressed", "onBackPressed")

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
        if key = "down" and m.activeTab = 0
            if m.focusIndex < 2
                m.focusIndex = m.focusIndex + 1
                updateFocus()
                handled = true
            end if
        else if key = "up" and m.activeTab = 0
            if m.focusIndex > 0
                m.focusIndex = m.focusIndex - 1
                updateFocus()
                handled = true
            end if
        else if key = "right" and m.activeTab = 0
           onFavoritesTabPressed()
           handled = true
        else if key = "OK" and m.activeTab = 0
            if m.focusIndex = 0
                openTextInputDialog("Email eingeben", m.emailValue, "email")
                handled = true
            else if m.focusIndex = 1
                openTextInputDialog("Passwort eingeben", m.passwordValue, "password")
                handled = true
            else if m.focusIndex = 2
                print "> SettingsScreen: login/logout button pressed"
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
    
    kbDialog = createObject("roSGNode", "KeyboardDialog")
    kbDialog.title = title
    kbDialog.text = currentText
    kbDialog.buttons = ["OK", "Abbrechen"]
    
    m.activeInputMode = mode
    m.dialogPane.appendChild(kbDialog)
    
    kbDialog.observeField("buttonSelected", "onDialogButtonSelected")
end sub

sub onDialogButtonSelected(event as Object)
    dialog = event.getRoSGNode()
    buttonIndex = dialog.buttonSelected
    print "Keyboard closed. Button index: "; buttonIndex; ", Text: "; dialog.text
    
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
End Function

Function updateLoginStatusUI() As Void
    loggedIn = m.global.loggedIn

    if loggedIn = true then
        ' Show logout button, hide save/login button
        m.logoutButton.visible = true
        m.loginButton.visible = false
        
        ' Enable Favorites tab when logged in
        m.FavoritesTabBtn.visible = true
        m.FavoritesTabIndicator.visible = true
    else
        ' Hide logout button, show save/login button
        m.logoutButton.visible = false
        m.loginButton.visible = true
        
        ' Disable Favorites tab when not logged in
        m.FavoritesTabBtn.visible = false
        m.FavoritesTabIndicator.visible = false
    end if

    ' Ensure Login tab is active when not logged in (Favorites unavailable)
    if loggedIn = false then
        switchToTab(0)
    end if
End Function

Function onAuthStateChanged() As Void
    updateLoginStatusUI()
End Function

'=============================================================================
' Tab Switching Logic
'=============================================================================

Function switchToTab(tabIndex as Integer) As Void
    m.activeTab = tabIndex

    if tabIndex = 0 then ' Login & Session tab
        m.LoginTabContent.visible = true
        m.FavoritesTabContent.visible = false
        
        ' Update tab indicators
        m.LoginTabIndicator.visible = true
        m.FavoritesTabIndicator.visible = false
        
        ' Update button colors
        m.LoginTabBtn.color = "#FFFFFF"
        m.FavoritesTabBtn.color = "#A0A5AE"
        
        m.LoginTabBtn.setFocus(true)
    else if tabIndex = 1 then ' Favorites tab
        m.LoginTabContent.visible = false
        m.FavoritesTabContent.visible = true
        
        ' Update tab indicators
        m.LoginTabIndicator.visible = false
        m.FavoritesTabIndicator.visible = true
        
        ' Update button colors
        m.LoginTabBtn.color = "#A0A5AE"
        m.FavoritesTabBtn.color = "#FFFFFF"
        
        m.FavoritesTabBtn.setFocus(true)
        m.channelList.setFocus(true)
        
        ' Fetch channels when switching to Favorites tab for the first time or if empty
        loadChannelsAndFavorites()
    end if
End Function

Function onLoginTabPressed() As Void
    switchToTab(0)
End Function

Function onFavoritesTabPressed() As Void
    switchToTab(1)
End Function

'=============================================================================
' Favorites Feature - Channel List & Selection
'=============================================================================

Function loadChannelsAndFavorites() As Void
    loadFavorites()
    httpManager = createObject("roSGNode", "HttpManager")
    
    ' If we already have channels, just rebuild the UI
    if m.channels <> invalid and m.channels.count() > 0 then
        buildChannelListUI()
        return
    end if

    showFavoritesStatus("Loading channels...", true)
    
    print "> SettingsScreen: fetching channel list from Zattoo API"

    result = httpManager.callFunc("getChannelList")
    
    if result.success then
        print "> SettingsScreen: channel list fetched successfully"
        
        parseChannelGroups(result.channels)
        buildChannelListUI()
        hideFavoritesStatus()
    else
        print "> SettingsScreen: failed to fetch channel list - " + result.error
        showFavoritesStatus("Failed to load channels. Please try again.", false)
    end if
End Function

Function parseChannelGroups(channelGroups as Object) As Void
    m.channels = []
    
    ' Handle both roArray and single object cases
    if type(channelGroups) = "roArray" then
        for each group in channelGroups
            if type(group) = "roAssociativeArray" and type(group.channels) = "roArray" then
                for each channel in group.channels
                    addChannelToMasterList(channel)
                end for
            else if type(group) = "roAssociativeArray" then
                addChannelToMasterList(group)
            end if
        next
    else if type(channelGroups) = "roAssociativeArray" and type(channelGroups.channels) = "roArray" then
        for each channel in channelGroups.channels
            addChannelToMasterList(channel)
        end for
    end if
    
    print "> SettingsScreen: parsed " + str(m.channels.count()) + " channels"
End Function

Function addChannelToMasterList(channel as Object) As Void
    channelId = channel.id.Trim()
    cid = channel.cid.Trim()
    title = channel.title.Trim()
    
    if channelId <> "" and title <> "" then
        m.channels.push({id: channelId, cid: cid, title: title})
    end if
End Function

Function buildChannelListUI() As Void
    m.channelList.content = invalid
    m.checkIdToCid.clear()
    
    if m.channels.count() = 0 then
        showFavoritesStatus("No channels available.", false)
        return
    end if
    
    print "> SettingsScreen: building channel list UI with " + str(m.channels.count()) + " channels"
    
    ' Create content node for the List
    content = createObject("roSGNode", "ContentNode")
    favoriteCheckedState = []
    
    for each channel in m.channels
        channelId = channel.id
        title = channel.title
        
        isFavorite = false
        if m.favorites.Count() > 0 and m.favorites[channelId] <> invalid then
            isFavorite = true
            
        end if

        favoriteCheckedState.push(isFavorite)
        m.checkIdToCid.push(channelId)
        
        ' Create content node for each channel row
        channelNode = createObject("roSGNode", "ContentNode")
        channelNode.TITLE = title
        content.appendChild(channelNode)
    next
    
    m.channelList.content = content
    m.channelList.checkedState = favoriteCheckedState
    
    ' Observe selection events from the List
    m.channelList.observeField("itemSelected", "onChannelSelected")
    
    print "> SettingsScreen: built UI for " + str(m.channels.count()) + " channels"
End Function

Function onChannelSelected(event as Object) As Void
    for i = 0 to m.channelList.checkedState.count() - 1
        channelId = m.checkIdToCid[i]
        isChecked = false
        if m.channelList.checkedState[i] then
            isChecked = true
        end if

        m.favorites[channelId] = isChecked
    next

    saveFavorites()
End Function

Function loadFavorites() As Void
    registry = CreateObject("roRegistrySection", "Favorites")
    
    m.favorites = {}
    
    keyList = registry.GetKeyList()
    
    for each key in keyList
        value = registry.Read(key)
        if value = "true" then
            m.favorites[key] = true
        end if
    next
    
    print "> SettingsScreen: loaded " + str(keyList.count()) + " favorites from registry"
End Function

Function saveFavorites() As Void
    registry = CreateObject("roRegistrySection", "Favorites")
    
    keyList = registry.GetKeyList()
    for each key in keyList
        registry.Delete(key)
    end for
    
    for each channelId in m.favorites
        if m.favorites[channelId] then
            registry.Write(channelId, "true")
        else
            registry.Write(channelId, "false")
        end if
    next
    
    success = registry.Flush()
    
    if success then
        print "> SettingsScreen: saved favorites to registry"
    else
        print "> SettingsScreen: Error saving favorites to registry"
    end if
End Function

Function showFavoritesStatus(message as String, isLoading as Boolean) As Void
    m.favoritesStatusLabel.text = message
    m.favoritesStatusLabel.visible = true
    
    if isLoading then
        m.favoritesStatusLabel.color = "#A0A5AE"
    else
        m.favoritesStatusLabel.color = "0xFF3333"
    end if
End Function

Function hideFavoritesStatus() As Void
    m.favoritesStatusLabel.text = ""
    m.favoritesStatusLabel.visible = false
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
    m.top.navigationRequest = "pop"
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
    m.statusLabel.text = message
    m.statusLabel.visible = true

    if success then
        m.statusLabel.color = "0x00AA00"
    else
        m.statusLabel.color = "0xFF3333"
    end if
End Function
