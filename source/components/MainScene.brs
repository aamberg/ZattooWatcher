sub init()
    m.screenContainer = m.top.findNode("screenContainer")
    m.screenStack = []
    
    showScreen("WelcomeScreen")
    
    m.top.setFocus(true)
end sub

sub showScreen(screenName as String)
    if m.screenStack.count() > 0
        currentScreen = m.screenStack.peek()
        m.screenContainer.removeChild(currentScreen)
        currentScreen.setFocus(false)
    end if

    newScreen = createObject("roSGNode", screenName)
    
    newScreen.observeField("navigationRequest", "onChildNavigationRequested")

    m.screenContainer.appendChild(newScreen)
    newScreen.setFocus(true)
    m.screenStack.push(newScreen)
end sub

sub onChildNavigationRequested(event as Object)
    targetScreen = event.getData()
    if targetScreen = "pop"
        popScreen()
    else if targetScreen <> ""
        showScreen(targetScreen)
    end if
end sub

sub popScreen()
    if m.screenStack.count() > 1
        oldScreen = m.screenStack.pop()
        oldScreen.setFocus(false)
        m.screenContainer.removeChild(oldScreen)
        
        previousScreen = m.screenStack.peek()
        m.screenContainer.appendChild(previousScreen) 
        previousScreen.setFocus(true)
        m.top.setFocus(true)
    end if
end sub

' Global remote control back button handling
function onKeyEvent(key as String, press as Boolean) as Boolean
    handled = false
    if press
        if key = "back"
            if m.screenStack.count() > 1
                popScreen()
                handled = true
            else
                ' If on the root screen, allow Roku to exit the app
                handled = false 
            end if
        end if
    end if
    return handled
end function