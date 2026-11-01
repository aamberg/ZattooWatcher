sub init()
    m.itemHighlight = m.top.findNode("itemHighlight")
    m.itemIcon = m.top.findNode("itemIcon")
    m.itemLabel = m.top.findNode("itemLabel")
    
    ' Explicitly observe itemContent changes
    m.top.observeField("itemContent", "onItemContentChange")
end sub

sub onItemContentChange()
    content = m.top.itemContent
    if content <> invalid
        print "SidebarItemComponent: itemContent changed to: "; content.title
        m.itemLabel.text = content.title
        m.itemIcon.uri = content.hdPosterUrl
    end if
end sub


sub onFocusPercentChanged()
    focusPercent = m.top.focusPercent
    if focusPercent > 0.5
        m.itemHighlight.opacity = 1.0
        m.itemLabel.color = "#FFFFFF"
    else
        m.itemHighlight.opacity = 0.0
        m.itemLabel.color = "#A0A5AE"
    end if
end sub