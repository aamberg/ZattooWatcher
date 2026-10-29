' HttpManager — Central HTTP layer for Zattoo API communication
' Supports GET/POST with cookies, session persistence, and retry logic

sub init() as Void
  m.port = CreateObject("roMessagePort")
  
  m.cookies = {}
  
  m.defaultHeaders = {
    "User-Agent": "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36",
    "Accept": "application/json"
  }
  
  m.timeoutMs = 15000
  m.maxRetries = 3
  m.retryDelayMs = 1000
  m.appVersion = "3.2120.1"
  m.powerGuideHash = ""
  m.accountIsActive = false
  m.logoBaseUrl = "https://images.zattic.com/logos"
  m.imageBaseUrl = "https://images.zattic.com/cms"
  
end sub

'=============================================================================
' Core HTTP Methods
'=============================================================================

function makeRequest(url as String, method as String, body as Object, headers as Object) as Object
  ' Create roUrlTransfer instance
  transfer = CreateObject("roUrlTransfer")
  
  if transfer = invalid then
    return { success: false, error: "Failed to create roUrlTransfer" }
  end if
  
  ' Set basic properties
  transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
  transfer.AddHeader("X-Roku-Reserved-Dev-Id", "")
  transfer.InitClientCertificates()
  
  transfer.SetTimeout(m.timeoutMs)
  transfer.SetUrl(transfer.urlEncode(url))
  
  ' Apply default headers
  if m.defaultHeaders <> invalid then
    for each key in m.defaultHeaders
      transfer.AddHeader(key, m.defaultHeaders[key])
    end for
  end if
  
  ' Apply custom headers (override defaults)
  if headers <> invalid and type(headers) = "roAssociativeArray" then
    for each key in headers
      transfer.AddHeader(key, headers[key])
    end for
  end if
  
  ' Add cookies from jar
  m.addCookiesToRequest(transfer, url)
  
  ' Execute request based on method
  result = invalid
  
  if method = "GET" then
    result = transfer.AsyncGetToString(m.port)
  else if method = "POST" then
    if body <> invalid and type(body) = "roString" then
      transfer.AddHeader("Content-Type", "application/json")
      result = transfer.AsyncPostFromString(m.port, body)
    else if body <> invalid and type(body) = "roAssociativeArray" then
      jsonBody = m.jsonToString(body)
      transfer.AddHeader("Content-Type", "application/json")
      result = transfer.AsyncPostFromString(m.port, jsonBody)
    else
      return { success: false, error: "Invalid body for POST request" }
    end if
  else
    return { success: false, error: "Unsupported HTTP method: " + method }
  end if
  
  if result = false then
    errorMsg = transfer.GetFailureString()
    responseCode = transfer.GetResponseCode()
    print "> HttpManager: request failed for '" + url + "' - " + errorMsg
    return { success: false, error: errorMsg, code: responseCode }
  end if
  
  ' Wait for async response
  msg = wait(5, m.port)
  
  if type(msg) = "roUrlEvent" then
    responseCode = msg.GetResponseCode()
    content = msg.GetString()
    
    print "> HttpManager: GET/POST '" + url + "' returned code " + str(responseCode)
    
    return { success: true, code: responseCode, content: content }
  else
    print "> HttpManager: unexpected response type for request"
    return { success: false, error: "Unexpected response type", code: -1 }
  end if
  
end function

'=============================================================================
' Retry Wrapper with Exponential Backoff
'=============================================================================

function makeRequestWithRetry(url as String, method as String, body as Object, headers as Object) as Object
  lastError = ""
  
  for i = 1 to m.maxRetries
    result = m.makeRequest(url, method, body, headers)
    
    if result.success then
      return result
    end if
    
    lastError = result.error
    
    ' Only retry on certain error codes (network issues, timeouts)
    if type(result.code) = "roInt" and (result.code >= 500 or result.code < 0) then
      print "> HttpManager: retrying request (" + str(i) + "/" + str(m.maxRetries) + ")"
      
      ' Wait with exponential backoff using roTimespan Sleep
      delayMs = m.retryDelayMs * i
      sleepTimer = CreateObject("roTimespan")
      sleepTimer.Sleep(delayMs)
    else
      print "> HttpManager: non-retryable error, stopping retries"
      exit for
    end if
  next
  
  return { success: false, error: "Request failed after " + str(m.maxRetries) + " retries. Last error: " + lastError }

end function

'=============================================================================
' Cookie Jar Management
'=============================================================================

function addCookiesToRequest(transfer as Object, url as String) as Void
  ' Simplified cookie handling - stores cookies by domain
  if m.cookies.count() = 0 then
    return
  end if
  
  domain = m.extractDomain(url)
  
  cookieString = ""
  
  for each path in m.cookies
    for each domainKey in m.cookies[path]
      if domainKey = domain or m.domainEndsWith(domain, domainKey) then
        for each name in m.cookies[path][domainKey]
          cookieValue = m.cookies[path][domainKey][name]
          cookieString += name + "=" + cookieValue.value + "; "
        end for
      end if
    end for
  next
  
  if cookieString <> "" then
    cookieString = m.trimRight(cookieString, "; ")
    transfer.AddHeader("Cookie", cookieString)
  end if
  
end function

function extractDomain(url as String) as String
  parts = url.split("//")
  if parts.count() > 1 then
    domainPart = parts[1]
    slashPos = Instr(domainPart, "/")
    if slashPos > 0 then
      return Mid(domainPart, 1, slashPos - 1)
    end if
    return domainPart
  end if
  
  return ""

end function

function domainEndsWith(domain as String, suffix as String) as Boolean
  suffixLen = Len(suffix)
  domainLen = Len(domain)
  
  if suffixLen > domainLen then
    return false
  end if
  
  return Right(domain, suffixLen) = suffix

end function

function trimRight(str as String, trimStr as String) as String
  while str <> "" and Right(str, Len(trimStr)) = trimStr
    str = Left(str, Len(str) - Len(trimStr))
  end while
  
  return str

end function

'=============================================================================
' Session Persistence (roPath + file I/O)
'=============================================================================

function loadSession() as Void
  ' Use drive:/ for persistent storage on Roku
  sessionDir = CreateObject("roPath", "drive:/session/")
  sessionFile = sessionDir.CreateObject("roPath", "session.json")
  
  readFile = CreateObject("roFileSystem")
  
  if readFile.Exists(sessionFile) then
    fileHandle = readFile.Open(sessionFile, "r")
    
    if fileHandle <> invalid then
      jsonText = ""
      jsonChunk = ""

      while fileHandle.Read(jsonChunk) > 0
        jsonText += jsonChunk
      end while
      
      fileHandle.Close()

      jsonData = ParseJson(jsonText)
      
      if type(jsonData) = "roAssociativeArray" then
        m.token = jsonData.token or ""
        m.sessionId = jsonData.sessionId or ""
        
        print "> HttpManager: loaded persisted session"
      end if
      
    end if
    
  end if
  
end function

function saveSession(token as String, sessionId as String) as Void
  ' Ensure directory exists using roPath
  dirPath = CreateObject("roPath", "drive:/session/")
  
  writeFile = CreateObject("roFileSystem")
  writeFile.CreateDirectory(dirPath)
  
  sessionFile = dirPath.CreateObject("roPath", "session.json")
  
  fileHandle = writeFile.Open(sessionFile, "w")
  
  if fileHandle <> invalid then
    sessionData = { token: token, sessionId: sessionId }
    jsonText = m.jsonToString(sessionData)
    
    fileHandle.Write(jsonText)
    fileHandle.Close()
    
    print "> HttpManager: saved session to disk"
  end if
  
end function

function clearSession() as Void
  m.cookies = {}
  m.token = ""
  m.sessionId = ""
  
  ' Remove persisted session file
  sessionDir = CreateObject("roPath", "drive:/session/")
  sessionFile = sessionDir.CreateObject("roPath", "session.json")
  
  deleteFile = CreateObject("roFileSystem")
  if deleteFile.Exists(sessionFile) then
    deleteFile.Delete(sessionFile)
    print "> HttpManager: cleared session from disk"
  end if
  
end function

'=============================================================================
' Zattoo API Convenience Methods
'=============================================================================

function getToken() as Object
  url = "https://www.zattoo.com/token.json"
  
  result = m.makeRequestWithRetry(url, "GET", invalid, invalid)
  
  if result.success then
    jsonResponse = ParseJson(result.content)
    
    if type(jsonResponse) = "roAssociativeArray" and type(jsonResponse.token) = "roString" then
      m.token = jsonResponse.token
      print "> HttpManager: token fetched successfully"
      return { success: true, token: m.token }
    else
      return { success: false, error: "Invalid token response", code: result.code }
    end if
    
  else
    return result
  end if
  
end function

function createSession() as Object
  url = "https://www.zattoo.com/zapi/v3/session/hello"
  uuid = m.generateUUIDv4()
  
  ' todo: set lang in settings
  body = { client_app_token: m.token, app_version: m.appVersion, format: "json", lang: "de", uuid: uuid }
  
  result = m.makeRequestWithRetry(url, "POST", body, invalid)
  
  if result.success then
    jsonResponse = ParseJson(result.content)
    
    if type(jsonResponse) = "roAssociativeArray" and type(jsonResponse.token) = "roString" then
      m.powerGuideHash = jsonResponse.power_guide_hash or ""
      m.accountIsActive = jsonResponse.active or false
      m.logoBaseUrl = jsonResponse.logo_base_url or "https://images.zattic.com/logos"
      m.imageBaseUrl = jsonResponse.image_base_url or "https://images.zattic.com/cms"
      
      print "> HttpManager: token fetched successfully"
      return { success: true, token: m.token }
    else
      return { success: false, error: "Invalid token response", code: result.code }
    end if

    print "> HttpManager: session created successfully"
    
    return { success: true, code: result.code }
  else
    return result
  end if
  
end function

function loginAccount(email as String, password as String) as Object
  url = "https://www.zattoo.com/zapi/v3/account/login"
  
  body = { login: email, password: password, remember: true, format: "json" }
  
  result = m.makeRequestWithRetry(url, "POST", body, invalid)
  
  if result.success then
    jsonResponse = ParseJson(result.content)
    
    if type(jsonResponse) = "roAssociativeArray" and type(jsonResponse.success) = "roBoolean" then
      if jsonResponse.success then
        print "> HttpManager: login successful"
        
        ' Persist session data
        m.saveSession(m.token, "")
        
        return { success: true, loggedIn: true }
      else
        errorMsg = jsonResponse.error or "Unknown login error"
        return { success: false, error: errorMsg, code: result.code }
      end if
      
    else
      return { success: false, error: "Invalid login response", code: result.code }
    end if
    
  else
    return result
  end if
  
end function

function getChannelList(params as Object) as Object
  url = "https://www.zattoo.com/zapi/v3/channels"
  
  if params <> invalid and type(params) = "roAssociativeArray" then
    queryString = ""
    for each key in params
      ' url encode whole url in makeRequest. If that does not work, we can encode params individually here.
      queryString += "&" + key + "=" + params[key]
    end for
    
    url = url + "?" + Mid(queryString, 2)
  end if
  
  result = m.makeRequestWithRetry(url, "GET", invalid, invalid)
  
  if result.success then
    return { success: true, channels: result.content }
  else
    return result
  end if
  
end function

function resolveStreamUrl(channelId as String) as Object
  url = "https://www.zattoo.com/zapi/v3/stream/" + channelId
  
  result = m.makeRequestWithRetry(url, "GET", invalid, invalid)
  
  if result.success then
    return { success: true, streamUrl: result.content }
  else
    return result
  end if
  
end function

'=============================================================================
' Utility Functions
'=============================================================================

function jsonToString(obj as Object) as String
  ' Simple JSON serialization for basic associative arrays and primitives
  ' Note: Roku does not have built-in JSON serialization in older versions
  
  if type(obj) = "roAssociativeArray" then
    jsonStr = "{"
    first = true
    
    for each key in obj
      value = obj[key]
      
      if first = false then
        jsonStr += ","
      end if
      
      first = false
      
      ' Handle different types
      if type(value) = "roString" then
        jsonStr += "\"" + key + "\":\"" + value + "\""
      else if type(value) = "roInt" or type(value) = "roFloat" then
        jsonStr += "\"" + key + "\":" + str(value)
      else if type(value) = "roBoolean" then
        tmpValue = "true"
        if value = false then
          tmpValue = "false"
        end if
        jsonStr += "\"" + key + "\":" + tmpValue
      else if value = invalid or value = "" then
        jsonStr += "\"" + key + "\":null"
      end if
    next
    
    jsonStr += "}"
    
    return jsonStr
  else if type(obj) = "roString" then
    return "\"" + obj + "\""
  else if type(obj) = "roInt" or type(obj) = "roFloat" then
    return str(obj)
  else if type(obj) = "roBoolean" then
    if obj = false then
      return "false"
    else
      return "true"
    end if
  end if
  
  return ""

end function

function generateUUIDv4() as String
    hexChars = "0123456789abcdef"
    uuid = ""
    
    for i = 1 to 36
        ' Insert hyphens at positions 9, 14, 19, and 24
        if i = 9 or i = 14 or i = 19 or i = 24 then
            uuid = uuid + "-"
        else if i = 15 then
            ' Version 4: The 13th character must always be '4'
            uuid = uuid + "4"
        else if i = 20 then
            ' Variant: The 17th character must be one of '8', '9', 'a', or 'b'
            variantChars = "89ab"
            rIndex = rnd(4) ' returns 1 to 4
            uuid = uuid + mid(variantChars, rIndex, 1)
        else
            ' Random hex digit (0-9, a-f)
            rIndex = rnd(16) ' returns 1 to 16
            uuid = uuid + mid(hexChars, rIndex, 1)
        end if
    end for
    
    return uuid
end function