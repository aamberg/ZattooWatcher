Sub init()
    m.ClockLabel = m.top.findNode("ClockLabel")
    m.LoginStatusCircle = m.top.findNode("LoginStatusCircle")
    m.LoginStatusLabel = m.top.findNode("LoginStatusLabel")
    m.LiveStreamingBtn = m.top.findNode("LiveStreamingBtn")
    m.SettingsBtn = m.top.findNode("SettingsBtn")
    m.ClockTimer = m.top.findNode("ClockTimer")
    
    m.ClockLabel.drawingStyles = {
        "default": {
            "fontSize":124
            "color": "#36322E"
        }
    }

    ' Set initial focus on Live Streaming button
    m.LiveStreamingBtn.setFocus(true)

    ' Start clock updates
    m.ClockTimer.observeField("fire", "updateClock")
    m.ClockTimer.control = "start"

    ' Read auth state from global node and update indicator
    ' testEndpoints()
    updateLoginStatus()

    ' Observe button presses for navigation
    m.LiveStreamingBtn.observeField("pressed", "onLiveStreamingPressed")
    m.SettingsBtn.observeField("pressed", "onSettingsPressed")
End Sub

function testEndpoints() as Void
    ' currently, you have to set the functionName you want to test in the TestTokenEndpoint component
    m.TestTokenTask = m.top.findNode("TestTokenTask")
    if m.TestTokenTask <> invalid then
        print "> [TEST] Starting token endpoint test..."
        m.TestTokenTask.control = "RUN"
        ' Observe results
        m.TestTokenTask.observeField("resultSuccess", "onTestResult")
        m.TestTokenTask.observeField("resultError", "onTestResult")
    end if
end function

Function updateClock() As Void
    currentTime = CreateObject("roDateTime")
    hours = currentTime.getHours().ToStr()
    minutes = currentTime.getMinutes().ToStr()

    ' Pad with leading zeros for 24h format HH:MM
    if hours.Len() < 2 then hours = "0" + hours
    if minutes.Len() < 2 then minutes = "0" + minutes

    m.ClockLabel.text = hours + ":" + minutes
End Function

Function updateLoginStatus() As Void
    loggedIn = m.global.loggedIn
    if loggedIn = true
        ' Green circle, logged in text
        m.LoginStatusCircle.color = "0x00FF00FF"
        m.LoginStatusLabel.text = "Logged in"
    else
        ' Red circle, not logged in text
        m.LoginStatusCircle.color = "0xFF0000FF"
        m.LoginStatusLabel.text = "Not logged in"
    end if
End Function

Function onLiveStreamingPressed() As Void
    ' Navigate to HomeScene (live streaming)
    m.top.browseTo("HomeScene")
End Function

Function onSettingsPressed() As Void
    ' Navigate to Settings Scene
    m.top.browseTo("SettingsScene")
End Function

' TEMPORARY TEST: Handler for token endpoint test results
Function onTestResult() As Void
    if m.TestTokenTask <> invalid then
        success = m.TestTokenTask.resultSuccess
        error = m.TestTokenTask.resultError or ""
        responseTime = m.TestTokenTask.responseTimeMs

        print "> [TEST] Test completed. Success: " + str(success)
        if success = true then
            print "> [TEST] Token endpoint works! Response time: " + str(responseTime) + "ms"
        else
            print "> [TEST] Error: " + error
        end if
    end if
End Function
