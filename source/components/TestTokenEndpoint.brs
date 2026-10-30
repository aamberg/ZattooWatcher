' TestTokenEndpoint — Temporary test task to verify HttpManager token endpoint works
' Run once on device, check console logs for detailed output

sub init() as Void
  print "> [TEST] TestTokenEndpoint initialized"
  m.top.functionName = "runTest"
end sub

function runTest() as Void
  httpManager = createObject("roSGNode", "HttpManager")
  
  if httpManager = invalid then
    print "> [TEST] FAIL: Could not create HttpManager node"
    m.resultSuccess = false
    m.resultError = "Could not create HttpManager node"
    return
  end if
  
  print "> [TEST] HttpManager created successfully"
  
  startTime = CreateObject("roTimespan")
  
  result = httpManager.callFunc("getToken")
  
  endTime = startTime.TotalMilliseconds()
  m.responseTimeMs = endTime
  
  print "> [TEST] getToken() returned: " + type(result)
  
  if type(result) = "roAssociativeArray" then
    if result.success = true then
      m.resultSuccess = true
      m.resultToken = result.token
      
      print "> [TEST] SUCCESS!"
      print "> [TEST] Token received: " + m.resultToken
      print "> [TEST] Response time: " + str(m.responseTimeMs) + "ms"
    else
      m.resultSuccess = false
      m.resultError = result.error
      
      print "> [TEST] FAIL: getToken() returned success=false"
      print "> [TEST] Error: " + m.resultError
      if type(result.code) = "roInt" then
        m.resultCode = result.code
        print "> [TEST] Response code: " + str(m.resultCode)
      end if
    end if
  else
    m.resultSuccess = false
    m.resultError = "Unexpected response type: " + type(result)
    
    print "> [TEST] FAIL: Unexpected response type"
  end if
  
end function
