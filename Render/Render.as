// ############################## MENU #############################

void RenderMenu() {
    if(UI::BeginMenu(podiumIconBlue + " " +pluginName)) {
        if(windowVisible) {
            if(UI::MenuItem("Hide")) {
                windowVisible = false;
            }
            if(UI::MenuItem("Force refresh")) {
                ForceRefresh();
            }
        } else {
            if(UI::MenuItem("Show")) {
                windowVisible = true;
            }
        }

        UI::EndMenu();
    }
}

// ############################## WINDOW RENDER #############################

void Render() {

    if(!UserCanUseThePlugin()){
        return;
    }

    if(displayMode == EnumDisplayMode::ALWAYS) {
        RenderWindows();
    } else if (UI::IsGameUIVisible() && displayMode == EnumDisplayMode::ALWAYS_EXCEPT_IF_HIDDEN_INTERFACE){
        RenderWindows();
    }

    if(displayMode == EnumDisplayMode::HIDE_WHEN_DRIVING){
        auto state = VehicleState::ViewingPlayerState();
        if(state is null) return;
        float currentSpeed = state.WorldVel.Length() * 3.6;
        if(currentSpeed >= hiddingSpeedSetting) return;

        RenderWindows();
    }
    
    
}

void RenderInterface(){
    if(!UserCanUseThePlugin()){
        return;
    }

    if(displayMode == EnumDisplayMode::ONLY_IF_OPENPLANET_MENU_IS_OPEN) {
        RenderWindows();
    }
}

// Render the refresh button after we check if it's visible
void RenderRefreshButton(){
    if(showRefreshButtonSetting && UI::IsOverlayShown()){
        if(UI::Button("Refresh")){
            ForceRefresh();
        }
    }
}


void RenderWindows(){
    auto app = cast<CTrackMania>(GetApp());
   
    
    int windowFlags = UI::WindowFlags::NoTitleBar | UI::WindowFlags::NoCollapse | UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoDocking | UI::WindowFlags::NoFocusOnAppearing;
    bool showRefreshButton = false;

    if (!UI::IsOverlayShown()) {
        windowFlags |= UI::WindowFlags::NoInputs;
    }

    if(leaderboardArray.Length == 0 && !failedRefresh){
        return;
    }

    //if this is true, we're probably on a map not uploaded to nadeo's server. we don't want to show the window
    if(leaderboardArray.Length == 1 && leaderboardArray[0].position == -1){
        return;
    }

    //we don't want to show the window if we're in the editor
    if(app.Editor !is null){
        return;
    }
        

    if(windowVisible && app.CurrentPlayground !is null){
        UI::Begin(pluginName, windowFlags);

        UI::BeginGroup();

        if(showPluginName){
            UI::Text(pluginName);
        }
        
        if(showPluginName && showSeparator){
            UI::Separator();
        }

        bool rendered = RenderInfoTab();
        
        RenderTab(!rendered);

        RenderRefreshButton();

        UI::EndGroup();

        UI::End();
    }
}

/**
 * Render the info tab
 * 
 * returns true if the refresh icon was rendered
 */
bool RenderInfoTab(){
    // if we don't show anything, we don't render the tab
    if(!(showMapName || showMapAuthor || showPlayerCount)){
        return false;
    }

    auto app = cast<CTrackMania>(GetApp());

    // To change where the refresh icon is rendered, we need to know if we rendered it or not
    bool refreshWasRendered = false;


    UI::BeginTable("Info", 4, UI::TableFlags::SizingFixedFit);
    UI::TableSetupColumn("info", UI::TableColumnFlags::WidthFixed);
    UI::TableSetupColumn("empty", UI::TableColumnFlags::WidthStretch);
    UI::TableSetupColumn("potentialRefresh", UI::TableColumnFlags::WidthFixed);
    UI::TableSetupColumn("playercount", UI::TableColumnFlags::WidthFixed);
    UI::TableNextRow();
    UI::TableNextColumn();
    if(app.RootMap !is null){
        if(showMapName){
            UI::Text(StripFormatCodes(app.RootMap.MapInfo.Name));
            UI::TableNextColumn();
            UI::TableNextColumn();
            UI::TableNextColumn();
            RenderRefreshIcon();
            refreshWasRendered = true;
        }
        
        UI::TableNextRow();
        UI::TableNextColumn();
        if(showMapAuthor){
            UI::Text(brightGreyColor + "Made by " + StripFormatCodes(app.RootMap.MapInfo.AuthorNickName));    
        }
        UI::TableNextColumn();
        UI::TableNextColumn();
        // if the refresh icon wasn't rendered, we render it here (for better alignment)
        if(!refreshWasRendered && (showMapAuthor || showPlayerCount)){
            RenderRefreshIcon();
            refreshWasRendered = true;
        }     
    }

    if(showPlayerCount && playerCount != -1){
        // set the text to be on the right
        UI::TableNextColumn();
        // if player count is above 10k, we display it as <10k
        string playerCountStr = NumberToString(playerCount);
        playerCountStr = playerCount > 10000 ? "<" + playerCountStr : playerCountStr;
        UI::Text(playerIconGrey + " " + playerCountStr);
    }

    UI::EndTable();

    return refreshWasRendered;
}

/**
 * Render the refresh icon if we're refreshing
 */
 void RenderRefreshIcon(){
    if(refreshPosition){
        UI::Text(refreshIconWhite);
        if(UI::IsItemHovered()){
            UI::BeginTooltip();
            UI::Text("Refreshing...");
            UI::EndTooltip();
        }
    }else if(failedRefresh){
        UI::Text(refreshIconWhite + warningIcon);
        if(UI::IsItemHovered()){
            UI::BeginTooltip();
            UI::Text("Refreshing failed.");
            UI::EndTooltip();
        }
    }
}

/**
 * Render the table with the custom leaderboard
 */
void RenderTab(bool showRefresh = false){
    UI::BeginTable("Main", 5);        
    
    UI::TableNextRow();
    UI::TableNextColumn();
    UI::TableNextColumn();
    UI::Text("Position");
    UI::TableNextColumn();
    UI::Text("Time");
    UI::TableNextColumn();
    if(showRefresh){
        RenderRefreshIcon();
    }
    UI::TableNextColumn();

    int i = 0;
    while(i < int(leaderboardArray.Length)){
            //We skip the pb if there's none
        if( 
            (leaderboardArray[i].entryType == EnumLeaderboardEntryType::PB && leaderboardArray[i].time == -1) ||
            (!showPb && leaderboardArray[i].entryType == EnumLeaderboardEntryType::PB) ){
            i++;
            continue;
        }

        // If the current record is a medal one, we make a display string based on the display mode
        string displayString = "";

        if(leaderboardArray[i].entryType == EnumLeaderboardEntryType::MEDAL){
            switch(medalDisplayMode){
                case EnumDisplayMedal::NORMAL:
                    break;
                case EnumDisplayMedal::IN_GREY:
                    displayString = greyColor;
                    break;                   
                default:
                    break;
            }
        }

        //------------POSITION ICON--------
        UI::TableNextRow();
        UI::TableNextColumn();
        UI::Text(GetIconForPosition(leaderboardArray[i].position));
        
        //------------POSITION-------------
        UI::TableNextColumn();
        if(leaderboardArray[i].position > 10000){
            UI::Text(displayString + "<" + NumberToString(leaderboardArray[i].position));
        }else{
            UI::Text(displayString + "" + NumberToString(leaderboardArray[i].position));
        }
        
        //------------TIME-----------------
        UI::TableNextColumn();
        UI::Text(displayString + TimeString(leaderboardArray[i].time));

        //------------HAS DESC-------------
        UI::TableNextColumn();
        if(leaderboardArray[i].desc != ""){
            UI::Text(displayString + leaderboardArray[i].desc);
        }
        
        //------------TIME DIFFERENCE------
        UI::TableNextColumn();

        if(showTimeDifference){
            if(leaderboardArray[i].time == -1 || timeDifferenceEntry.time == -1){
                //Nothing here, no time to compare to
            }else if(leaderboardArray[i].customEquals(timeDifferenceEntry)){
                //Nothing here, the position is the same, it's the same time
                //still keeping the if in case we want to print/add something here
            }else{
                int timeDifference = leaderboardArray[i].time - timeDifferenceEntry.time;
                string timeDifferenceString = TimeString(Math::Abs(timeDifference));
                
                if(inverseTimeDiffSign){
                    if(timeDifference < 0){
                        UI::Text((showColoredTimeDifference ? redColor : "") + "+" + timeDifferenceString);
                    }else{
                        UI::Text((showColoredTimeDifference ? blueColor : "") + "-" + timeDifferenceString);
                    }
                }else{
                    if(timeDifference < 0){
                        UI::Text((showColoredTimeDifference ? blueColor : "") + "-" + timeDifferenceString);
                    }else{
                        UI::Text((showColoredTimeDifference ? redColor : "") + "+" + timeDifferenceString);
                    }
                }
            }
        }

        i++;
            
    }

    UI::EndTable();
}