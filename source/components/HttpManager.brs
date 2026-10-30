' HttpManager — Central HTTP layer for Zattoo API communication
' Supports GET/POST with cookies, session persistence, and retry logic

sub init() as Void
  m.port = createObject("roMessagePort")
  m.cookies = {}
  
  m.defaultHeaders = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36",
    "Accept": "application/json",
    "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
    "X-Requested-With": "XMLHttpRequest",
    "Referer": "https://www.zattoo.com/client"
  }
  
  m.timeoutMs = 15000
  m.maxRetries = 3
  m.retryDelayMs = 1000
  m.appVersion = "3.2120.1"
  m.powerGuideHash = ""
  m.accountIsActive = false
  m.token = ""
  m.logoBaseUrl = "https://images.zattic.com/logos"
  m.imageBaseUrl = "https://images.zattic.com/cms"

  loadCookies()
  loadSession()
  
end sub

'=============================================================================
' Core HTTP Methods
'=============================================================================

function makeRequest(url as String, method as String, body as Object, headers as Object) as Object
  transfer = CreateObject("roUrlTransfer")
  
  if transfer = invalid then
    return { success: false, error: "Failed to create roUrlTransfer" }
  end if
  
  transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
  transfer.AddHeader("X-Roku-Reserved-Dev-Id", "")
  transfer.InitClientCertificates()
  
  transfer.SetUrl(url)
  transfer.SetPort(m.port)

  print "> HttpManager: making request to '" + url + "'"
  print "> HttpManager: method: " + method
  if m.defaultHeaders <> invalid then
    for each key in m.defaultHeaders
      transfer.AddHeader(key, m.defaultHeaders[key])
    end for
  end if
  
  if headers <> invalid and type(headers) = "roAssociativeArray" then
    for each key in headers
      transfer.AddHeader(key, headers[key])
    end for
  end if
  
  addCookiesToRequest(transfer, url)
  
  result = invalid
  
  if method = "GET" then
    result = transfer.AsyncGetToString()
  else if method = "POST" then
    if body <> invalid and type(body) = "roString" then
      print "> HttpManager: making POST request with string body"
      print "> HttpManager: body: " + body
      result = transfer.AsyncPostFromString(body)
    else if body <> invalid and type(body) = "roAssociativeArray" then
      jsonBody = FormatJson(body)
      transfer.AddHeader("Content-Type", "application/json")
      print "> HttpManager: making POST request with JSON body"
      print "> HttpManager: body: " + jsonBody
      result = transfer.AsyncPostFromString(jsonBody)
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
  
  msg = wait(0, m.port)
  
  if type(msg) = "roUrlEvent" then
    responseCode = msg.GetResponseCode()
    content = msg.GetString()
    
    print "> HttpManager: GET/POST '" + url + "' returned code " + str(responseCode)
    
    if responseCode >= 200 and responseCode < 300 then
      parseSetCookieHeaders(msg, url)
      saveCookies()
    end if
    
    return { success: true, code: responseCode, content: content }
  else
    print "> HttpManager: unexpected response type for request: " + type(msg)
    return { success: false, error: "Unexpected response type", code: -1 }
  end if
  
end function

'=============================================================================
' Retry Wrapper with Exponential Backoff
'=============================================================================

function makeRequestWithRetry(url as String, method as String, body as Object, headers as Object) as Object
  lastError = ""
  
  for i = 1 to m.maxRetries
    result = makeRequest(url, method, body, headers)
    
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
' Cookie Persistence (load/save cookies to disk)
'=============================================================================

function loadCookies() as Void
  cookieFile = "cachefs:/zattooWatcher/cookies.json"  
  readFile = CreateObject("roFileSystem")
  
  if readFile.Exists(cookieFile) then
    jsonString = ReadAsciiFile(cookieFile)
    
    if jsonString <> "" then
      jsonData = ParseJson(jsonString)
      
      if type(jsonData) = "roAssociativeArray" then
        m.cookies = jsonData
        print "> HttpManager: loaded persisted cookies (" + str(m.cookies.count()) + " entries)"
      end if
      
    end if
  end if
end function

function saveCookies() as Void
  cookieFile = "cachefs:/zattooWatcher/cookies.json"  
  jsonString = FormatJson(m.cookies)
  
  if jsonString <> invalid then
    success = WriteAsciiFile(cookieFile, jsonString)
    if success then
        print "> HttpManager: saved cookies to disk (" + cookieFile + ")"
    else
        print "> HttpManager: Error: Failed to write cookie file."
    end if
    
  end if
end function

'=============================================================================
' Cookie Jar Management
'=============================================================================

function addCookiesToRequest(transfer as Object, url as String) as Void
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

function parseSetCookieHeaders(msg as Object, url as String) as Void
  if msg = invalid then
    return
  end if
  
  domain = extractDomain(url)
  path = ""
  
  responseHeaders = msg.GetResponseHeaders() 
  setCookieValue = responseHeaders["Set-Cookie"]
  
  if type(setCookieValue) = "roString" and setCookieValue <> "" then
    parseSingleSetCookie(setCookieValue, domain, path)
  end if
  
end function

function parseSingleSetCookie(setCookieValue as String, defaultDomain as String, defaultPath as String) as Void
  if setCookieValue = "" then
    return
  end if
  
  name = ""
  value = ""
  domain = defaultDomain
  path = defaultPath
  expires = ""
  maxAge = ""
  secure = false
  httpOnly = false
  
  parts = setCookieValue.Split(";")
  
  if parts.count() > 0 then
    firstPart = trimLeft(trimRight(parts[0], " "), " ")
    equalsPos = Instr(firstPart, "=")
    
    if equalsPos > 0 then
      name = trimLeft(trimRight(Mid(firstPart, 1, equalsPos - 1), " "), " ")
      value = trimLeft(trimRight(Mid(firstPart, equalsPos + 1), " "), " ")
    end if
    
    for i = 2 to parts.count()
      attr = trimLeft(trimRight(parts[i - 1], " "), " ").ToLower()
      
      if attr = "domain" or Left(attr, 9) = "domain=" then
        domainValue = Mid(attr, 8)
        domain = trimLeft(trimRight(domainValue, " "), " ")
      else if attr = "path" or Left(attr, 6) = "path=" then
        pathValue = Mid(attr, 7)
        path = trimLeft(trimRight(pathValue, " "), " ")
      else if attr = "expires" or Left(attr, 9) = "expires=" then
        expires = Mid(attr, 10)
      else if attr = "max-age" or Left(attr, 8) = "max-age=" then
        maxAge = Mid(attr, 9)
      else if attr = "secure" then
        secure = true
      else if attr = "httponly" then
        httpOnly = true
      end if
    next
  end if
  
  if name <> "" and value <> "" then
    if m.cookies[path] = invalid then
      m.cookies[path] = {}
    end if
    
    if m.cookies[path][domain] = invalid then
      m.cookies[path][domain] = {}
    end if
    
    m.cookies[path][domain][name] = { value: value, domain: domain, path: path }
    print "> HttpManager: stored cookie '" + name + "' for domain '" + domain + "'"
  end if
  
end function

'=============================================================================
' Session Persistence (roPath + file I/O)
'=============================================================================

function loadSession() as Void
  sessionFile = "cachefs:/zattooWatcher/session.json"  
  readFile = CreateObject("roFileSystem")
  
  if readFile.Exists(sessionFile) then
    jsonString = ReadAsciiFile(sessionFile)
    
    if jsonString <> "" then
      jsonData = ParseJson(jsonString)
      
      if type(jsonData) = "roAssociativeArray" then
        m.token = jsonData.token or ""
        m.powerGuideHash = jsonData.powerGuideHash or ""
        print "> HttpManager: loaded persisted session"
      end if
      
    end if
  end if  
end function

function saveSession() as Void
  sessionFile = "cachefs:/zattooWatcher/session.json"
  sessionData = { token: m.token, powerGuideHash: m.powerGuideHash }
  jsonString = FormatJson(sessionData)
  
  if jsonString <> invalid then
    success = WriteAsciiFile(sessionFile, jsonString)
    if success then
        print "> HttpManager: saved session to disk (" + sessionFile + ")"
    else
        print "> HttpManager: Error: Failed to write session file."
    end if
    
  end if
  
end function

function clearSession() as Void
  m.cookies = {}
  m.token = ""
  m.powerGuideHash = ""
  
  sessionFile = "cachefs:/zattooWatcher/session.json"
  cookieFile = "cachefs:/zattooWatcher/cookies.json"
  
  deleteFile = CreateObject("roFileSystem")

  if deleteFile.Exists(sessionFile) then
    deleteFile.Delete(sessionFile)
    print "> HttpManager: cleared session from disk"
  end if
  
  if deleteFile.Exists(cookieFile) then
    deleteFile.Delete(cookieFile)
    print "> HttpManager: cleared cookies from disk"
  end if
  
end function

'=============================================================================
' Zattoo API Convenience Methods
'=============================================================================

function getToken() as Object
  url = "https://www.zattoo.com/token.json"
  
  result = makeRequestWithRetry(url, "GET", invalid, invalid)
  
  if result.success then
    jsonResponse = ParseJson(result.content)
    
    if type(jsonResponse) = "roAssociativeArray" and type(jsonResponse.session_token) = "String" then
      m.token = jsonResponse.session_token
      saveSession()

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
  transfer = CreateObject("roUrlTransfer")
  url = "https://zattoo.com/zapi/v3/session/hello"
  uuid = generateUUIDv4()
  
  print "> HttpManager: create hello session with UUID: " + uuid
  print "> HttpManager: using token: " + m.token

  ' todo: set lang in settings
  body = "client_app_token=" + transfer.Escape(m.token) + "&app_version=" + transfer.Escape(m.appVersion) + "&format=json&lang=de&uuid=" + transfer.Escape(uuid)
  
  result = makeRequestWithRetry(url, "POST", body, invalid)
  
  if result.success then
    jsonResponse = ParseJson(result.content)
    
    if type(jsonResponse) = "roAssociativeArray" and jsonResponse.active = true then
      print "> HttpManager: hello successfully"
      return { success: true, data: jsonResponse }
    else
      return { success: false, error: "Invalid createSession response", code: result.code }
    end if

  else
    return result
  end if
  
end function

function loginAccount(email as String, password as String) as Object
  transfer = CreateObject("roUrlTransfer")
  url = "https://zattoo.com/zapi/v3/account/login"
  
  body = "login=" + transfer.Escape(email) + "&password=" + transfer.Escape(password) + "&remember=true&format=json"
  
  result = m.makeRequestWithRetry(url, "POST", body, invalid)
  
  if result.success then
    jsonResponse = ParseJson(result.content)
    
    if type(jsonResponse) = "roAssociativeArray" and jsonResponse.active = true then
      m.powerGuideHash = jsonResponse.power_guide_hash or ""
      m.accountIsActive = jsonResponse.active or false
      m.logoBaseUrl = jsonResponse.logo_base_url or "https://images.zattic.com/logos"
      m.imageBaseUrl = jsonResponse.image_base_url or "https://images.zattic.com/cms"
      
      print "> HttpManager: login successful"
        
      return { success: true, loggedIn: true }
    else
      return { success: false, error: "Invalid login response", code: result.code }
    end if
    
  else
    return result
  end if
  
end function

function getChannelList() as Object
  url = "https://zattoo.com/zapi/v2/cached/channels/" + m.powerGuideHash + "?details=False"
  result = m.makeRequestWithRetry(url, "GET", invalid, invalid)
  
  if result.success then
    jsonResponse = ParseJson(result.content)

    if type(jsonResponse) = "roAssociativeArray" and jsonResponse.success = true then
      print "> HttpManager: channel list fetched successfully"

      return { success: true, channels: jsonResponse.channel_groups }
    else
      return { success: false, error: "Invalid channel list response", code: result.code }
    end if

    
  else
    return result
  end if
  
end function

function resolveStreamUrl(channelId as String) as Object
  transfer = CreateObject("roUrlTransfer")
  url = "https://zattoo.com/zapi/watch"
  
  ' hls7 currently set as default. (maybe only hls7 is supported on roku?)
  body = "https_watch_urls=true&stream_type=hls7&cid=" + transfer.Escape(channelId)
  
  result = m.makeRequestWithRetry(url, "POST", body, invalid)
  
  if result.success then
    jsonResponse = ParseJson(result.content)

    if type(jsonResponse) = "roAssociativeArray" and jsonResponse.success = true then
      print "> HttpManager: channel urls resolved successfully"

      ' Note: jsonResponse.url is also available, sometiomes with hd stream. Maybe merge both urls and pick the best one? For now, just return watch_urls.
      return { success: true, watchUrls: jsonResponse.watch_urls }
    else
      return { success: false, error: "Invalid channel urls response", code: result.code }
    end if
  else
    return result
  end if
  
end function

'=============================================================================
' Utility Functions
' mostly common functions that Roku does not have built-in (at least i did not find them)
'=============================================================================

function jsonToString(obj as Object) as String
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


function trimLeft(str as String, trimStr as String) as String
  while str <> "" and Left(str, Len(trimStr)) = trimStr
    str = Mid(str, Len(trimStr) + 1)
  end while
  
  return str

end function