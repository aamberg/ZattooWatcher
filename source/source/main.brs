
sub Main()
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)

    m.global = screen.getGlobalNode()
    m.global.addField("Model", "int", true)
    m.global.Model = 0
    m.global.addField("Options", "int", true)
    m.global.Options = 2
    m.global.addField("loggedIn", "boolean", true)
    m.global.loggedIn = false

    dev = createObject("roDeviceInfo")
    model = (Left(dev.GetModel(),1)).toInt()
    if model < 4
        m.global.Model = 1
    end if
    
    if m.global.loggedIn = true
        scene = screen.CreateScene("HomeScene")
        screen.show()
        
        m.RowList = scene.findNode("RowList")
        m.RowList.observeField("rowItemSelected", m.port)
        
        m.Video = scene.findNode("Video")
    end if

    while(true)
       msg = wait(0, m.port)
	   msgType = type(msg)
       if msgType = "roSGScreenEvent"
            print msg
            if msg.isScreenClosed() then return
       end if
    end while
end sub