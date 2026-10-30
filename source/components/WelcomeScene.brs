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
    'testEndpoints()
    updateLoginStatus()
    CallApiAndReadCookies()

    ' Observe button presses for navigation
    m.LiveStreamingBtn.observeField("pressed", "onLiveStreamingPressed")
    m.SettingsBtn.observeField("pressed", "onSettingsPressed")
End Sub

sub CallApiAndReadCookies()
    url = "https://zattoo.com/zapi/v3/session/hello"
    
    
    ' 1. Create message port and roUrlTransfer object
    port = CreateObject("roMessagePort")
    request = CreateObject("roUrlTransfer")

    payload = "client_app_token=" + request.Escape("") + "&app_version=" + request.Escape("3.2120.1") + "&format=json&lang=de&uuid=" + request.Escape("e4f478df-903e-441f-a1f8-56b2a78f60af")
    
    request.SetUrl(url)
    request.SetMessagePort(port)
    
    ' Ensure proper SSL handling for HTTPS requests
    if url.InStr(0, "https") = 0 then
        request.SetCertificatesFile("common:/certs/ca-bundle.crt")
        request.InitClientCertificates()
    end if

    ' 2. Enable automatic cookie parsing and storage in the cookie jar
    request.EnableCookies()
    
    ' 3. Set required headers (e.g., JSON content type)
    request.AddHeader("Content-Type", "application/x-www-form-urlencoded; charset=UTF-8")
    
    ' 4. Initiate the asynchronous POST request
    started = request.AsyncPostFromString(payload)
    
    if started then
        ' 5. Wait for the response event (timeout set to 10000ms / 10 seconds here)
        msg = wait(10000, port)
        
        if type(msg) = "roUrlEvent"
            code = msg.GetResponseCode()
            
            if code >= 200 and code < 300
                responseString = msg.GetString()
                print "API Request successful! Response: "; responseString
                
                ' 6. Read cookies from the request object's cookie cache after completion
                cookies = request.GetCookies("", "/")
                
                if cookies <> invalid and cookies.Count() > 0 then
                    print "--- Retrieved Cookies ---"
                    for each cookie in cookies
                        print "Name:  "; cookie.Name
                        print "Value: "; cookie.Value
                        print "Domain:"; cookie.Domain
                        print "Path:  "; cookie.Path
                        print "-------------------------"
                    end for
                else
                    print "No cookies found in the cookie jar."
                end if
            else
                print "API request failed with response code: "; code
            end if
        else
            print "Request timed out or an error occurred."
        end if
    else
        print "Failed to initiate AsyncPostFromString."
    end if
end sub

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
