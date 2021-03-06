;- IGame Tool Version 2
;
; Version 0.4 Test Alpha
;
; © 2021 Paul Vince (MrV2k)
;
; https://easymame.mameworld.info
;
; [ PB V5.7x/V6.x / 32Bit / 64Bit / Windows / DPI ]
;
; A converter for IGame CSV game lists.
;
; ====================================================================
;
; Initial Release
;
; ====================================================================
;
; Version 0.2
;
; Added check to prevent the loading of non CSV files.
; Added warning in help file about old IGame versions.
;
; ====================================================================
;
; Version 0.3
;
; Added edit window for full/short names and genres.
; Improved the help file.
;
; ====================================================================
;
; Version 0.4
;
; Fixed bug if game folders are in the root of the drive path
; Added slave edit box
; Added ability to save in different cases
;
; ====================================================================
;
;- ### Enumerations ###

EnableExplicit

Enumeration
  #MAIN_WINDOW
  #EDIT_WINDOW
  #MAIN_LIST
  #LOAD_BUTTON
  #SAVE_BUTTON
  #FIX_BUTTON
  #CLEAR_BUTTON
  #HELP_BUTTON
  #TAG_BUTTON
  #UNDO_BUTTON
  #HELP_WINDOW
  #LOADING_WINDOW
  #HELP_EDITOR
  #SHORT_NAME_CHECK
  #KEEP_DATA_CHECK
  #DUPE_CHECK
  #UNKNOWN_CHECK
  #FTP
  #EDIT_NAME
  #EDIT_SHORT
  #EDIT_GENRE
  #CASE_COMBO
  #EDIT_SLAVE
EndEnumeration

;- ### Structures ###

Structure UM_Data
  UM_Name.s
  UM_Path.s
  UM_Genre.s
  UM_Slave.s
  UM_Short.s
  UM_Data_1.s
  UM_Data_2.s
  UM_Data_3.s
  UM_Data_4.s
  UM_Folder.s
  UM_Filtered.b
  UM_Unknown.b
EndStructure

Structure Comp_Data
  C_Name.s
  C_Short.s
  C_Slave.s
  C_Folder.s
  C_Genre.s
EndStructure

;- ### Lists ###

Global NewList UM_Database.UM_Data()
Global NewList Undo_Database.UM_Data()
Global NewList Comp_Database.Comp_Data()
Global NewList Filtered_List.i()

;- ### Global Variables ###

Global Version.s="0.4 Test Alpha"
Global Keep_Data.b=#True
Global Short_Names.b=#False
Global Filter.b=#False
Global Unknown.b=#False
Global event, gadget, close.b
Global Name.s, CSV_Path.s
Global Home_Path.s=GetCurrentDirectory()
Global Output_Case.i=0

;- ### Macros ###

Macro Pause_Window(window)
  SendMessage_(WindowID(window),#WM_SETREDRAW,#False,0)
EndMacro

Macro Resume_Window(window)
  SendMessage_(WindowID(window),#WM_SETREDRAW,#True,0)
  RedrawWindow_(WindowID(window),#Null,#Null,#RDW_INVALIDATE)
EndMacro

Macro Message_Window(message)
  OpenWindow(#LOADING_WINDOW,0,0,150,50,message,#PB_Window_Tool|#PB_Window_WindowCentered,WindowID(#MAIN_WINDOW))
  TextGadget(#PB_Any,10,12,130,25,"Please Wait...", #PB_Text_Center)
EndMacro

Macro Backup_Database(state)
  
  CopyList(UM_Database(),Undo_Database())
  DisableGadget(#UNDO_BUTTON,state)
  
EndMacro

;- ### Procedures ###

Procedure Load_GL()
  
  Protected o_path$, path.s
  
  path=OpenFileRequester("Open "+o_path$+" List","","*.*",0)
  
  ClearList(UM_Database())
  
  If path<>""
    
    SetWindowTitle(#MAIN_WINDOW, "Loading Gameslist...")
        
    Protected igfile, count
    Protected instring.s, ipath.s, ifile.s
    
    If ReadFile(igfile,path)
      
      While Not Eof(igfile)
        
        count=2
        instring=ReadString(igfile)
        If instring="" : Continue : EndIf
        If FindString(instring,"title=")
          AddElement(UM_Database())
          UM_Database()\UM_Genre="Unknown"
          UM_Database()\UM_Name=Trim(Right(instring,Len(instring)-FindString(instring,"=")))
        EndIf
        
        If FindString(instring,"genre=")
          UM_Database()\UM_Genre=Right(instring,Len(instring)-FindString(instring,"="))
        EndIf
        
        If FindString(instring,"path=")
          UM_Database()\UM_Path=GetPathPart(Right(instring,Len(instring)-FindString(instring,"=")))
          count=CountString(UM_Database()\UM_Path,"/")
          UM_Database()\UM_Folder=StringField(UM_Database()\UM_Path,count,"/")+"/"
          UM_Database()\UM_Slave=GetFilePart(Right(instring,Len(instring)-FindString(instring,"=")))
        EndIf     
        
        If FindString(instring,"favorite=")
          UM_Database()\UM_Data_1=Right(instring,Len(instring)-FindString(instring,"="))
        EndIf
        If FindString(instring,"timesplayed=")
          UM_Database()\UM_Data_2=Right(instring,Len(instring)-FindString(instring,"="))
        EndIf
        If FindString(instring,"lastplayed=")
          UM_Database()\UM_Data_3=Right(instring,Len(instring)-FindString(instring,"="))
        EndIf
        If FindString(instring,"hidden=")
          UM_Database()\UM_Data_4=Right(instring,Len(instring)-FindString(instring,"="))
        EndIf
    
  Wend
  
  CloseFile(igfile) 
  
Else
  MessageRequester("Error","Error Reading File",#PB_MessageRequester_Error|#PB_MessageRequester_Ok)
EndIf

EndIf

EndProcedure

Procedure Save_CSV()
  
  Protected igfile, output$, path.s, response
  
  path=""
  
  If FileSize(CSV_Path)>-1
    response=MessageRequester("Warning","Overwrite Old Game List?"+Chr(10)+"Select 'No' to create a new file.",#PB_MessageRequester_YesNoCancel|#PB_MessageRequester_Warning)
    Select response
      Case #PB_MessageRequester_Yes : path=CSV_Path
      Case #PB_MessageRequester_No : path=OpenFileRequester("New File", "", "CSV File (*.csv)|*.csv",0)
    EndSelect 
  EndIf
  
  If GetExtensionPart(path)<>"csv" : path+".csv" : EndIf
  
  If response<>#PB_MessageRequester_Cancel And path<>""
    If CreateFile(igfile, path,#PB_Ascii)     
      ForEach UM_Database()
        output$="0;"
        If Short_Names
          output$+UM_Database()\UM_Short+";"
        Else
          output$+UM_Database()\UM_Name+";"
        EndIf
        output$+UM_Database()\UM_Genre+";" 
        If Output_Case=1
          output$=LCase(output$)
        EndIf
        If Output_Case=2
          output$=UCase(output$)
        EndIf
        output$+UM_Database()\UM_Path+UM_Database()\UM_Slave+";"
        If Not Keep_Data
          output$+"0;0;0;0"
        Else
          output$+UM_Database()\UM_Data_1+";"
          output$+UM_Database()\UM_Data_2+";"
          output$+UM_Database()\UM_Data_3+";"
          output$+UM_Database()\UM_Data_4
        EndIf
 
        WriteString(igfile,output$+#LF$)
      Next
      FlushFileBuffers(igfile)
      CloseFile(igfile)  
    EndIf
  EndIf
  
EndProcedure

Procedure Load_CSV()

  Protected CSV_File.i, Text_Data.s, Text_String.s
  Protected Count.i, I.i, Backslashes.i, Text_Line.s
  
  CSV_Path=OpenFileRequester("Open CSV","gameslist.csv","CSV File (*.csv)|*.csv",0)
  
  If CSV_Path<>""

    If ReadFile(CSV_File,CSV_Path,#PB_UTF8)
      
      Message_Window("Loading Game List...")
      
      Repeat
        Text_String=ReadString(CSV_File)
        If Not FindString(Text_String,";") 
          MessageRequester("Error", "Not A CSV File!",#PB_MessageRequester_Error|#PB_MessageRequester_Ok)
          CloseFile(CSV_File)
          CloseWindow(#LOADING_WINDOW)
          DisableGadget(#FIX_BUTTON,#True)
          DisableGadget(#SAVE_BUTTON,#True)
          DisableGadget(#KEEP_DATA_CHECK,#True)
          DisableGadget(#CLEAR_BUTTON,#True)
          DisableGadget(#TAG_BUTTON,#True)
          DisableGadget(#DUPE_CHECK,#True)
          DisableGadget(#SHORT_NAME_CHECK,#True)
          DisableGadget(#DUPE_CHECK,#True)
          DisableGadget(#CASE_COMBO,#True)
          Short_Names=#False
          Filter=#False
          Unknown=#False
          Output_Case=0
          SetGadgetState(#CASE_COMBO,Output_Case)
          SetGadgetState(#SHORT_NAME_CHECK,Short_Names)
          SetGadgetState(#DUPE_CHECK,Filter)
          SetGadgetState(#UNKNOWN_CHECK,Unknown)
          Break
        EndIf
        Text_Data+Text_String+#LF$
      Until Eof(CSV_File)
      
      If Text_Data="" : Goto Proc_Exit : EndIf
      
      CloseFile(CSV_File)  
      
      Count=CountString(Text_Data,#LF$)
      
      ClearList(UM_Database())
      
      For i=1 To count
        AddElement(UM_Database())
        Text_Line=StringField(Text_Data,i,#LF$)
        UM_Database()\UM_Name=StringField(Text_Line,2,";")
        UM_Database()\UM_Genre=StringField(Text_Line,3,";")
        UM_Database()\UM_Path=GetPathPart(StringField(Text_Line,4,";"))
        If CountString(UM_Database()\UM_Path,"/")>1
          Backslashes=CountString(UM_Database()\UM_Path,"/")
          UM_Database()\UM_Folder=StringField(UM_Database()\UM_Path,Backslashes,"/")
        Else
          Backslashes=CountString(UM_Database()\UM_Path,":")
          UM_Database()\UM_Folder=StringField(UM_Database()\UM_Path,Backslashes+1,":")
          UM_Database()\UM_Folder=RemoveString(UM_Database()\UM_Folder,"/")
        EndIf
        UM_Database()\UM_Slave=GetFilePart(StringField(Text_Line,4,";"))
        UM_Database()\UM_Data_1=StringField(Text_Line,5,";")
        UM_Database()\UM_Data_2=StringField(Text_Line,6,";")
        UM_Database()\UM_Data_3=StringField(Text_Line,7,";")
        UM_Database()\UM_Data_4=StringField(Text_Line,8,";")
        UM_Database()\UM_Filtered=#False
      Next
      
      DisableGadget(#FIX_BUTTON,#False)
      DisableGadget(#SAVE_BUTTON,#False)
      DisableGadget(#KEEP_DATA_CHECK,#False)
      DisableGadget(#CLEAR_BUTTON,#False)
      DisableGadget(#TAG_BUTTON,#False)
      DisableGadget(#DUPE_CHECK,#False)
      DisableGadget(#CASE_COMBO,#False)
      
      CloseWindow(#LOADING_WINDOW)
      
    EndIf
    
  Else
    MessageRequester("Error", "No File Selected!", #PB_MessageRequester_Error|#PB_MessageRequester_Ok)
  EndIf  
  
  SortStructuredList(UM_Database(),#PB_Sort_Ascending|#PB_Sort_NoCase,OffsetOf(UM_Data\UM_Name),TypeOf(UM_Data\UM_Name))

  Backup_Database(#True)
  
  Proc_Exit:
  
EndProcedure

Procedure Filter_List()
   
  Protected Previous.s
  
  ClearList(Filtered_List())
  
  ForEach UM_Database()  
    UM_Database()\UM_Filtered=#False
    If Filter
      If UM_Database()\UM_Name=Previous   
        UM_Database()\UM_Filtered=#True
        PreviousElement(UM_Database())
        UM_Database()\UM_Filtered=#True
        NextElement(UM_Database())
      EndIf     
      previous=UM_Database()\UM_Name
    EndIf
    If Unknown
      If UM_Database()\UM_Unknown=#True
        UM_Database()\UM_Filtered=#True
      EndIf
    EndIf
  Next
  
  ForEach UM_Database()
    If UM_Database()\UM_Filtered=#True
      AddElement(Filtered_List())
      Filtered_List()=ListIndex(UM_Database())
    EndIf
  Next
    
EndProcedure

Procedure Load_DB()
  
  Protected CSV_File.i, Path.s, Text_Data.s, Text_String.s
  Protected Count.i, I.i, Backslashes.i, Text_Line.s
  
  path=Home_Path+"UM_Data"
  
  If path<>""
    
    If ReadFile(CSV_File,Path,#PB_Ascii)
      Repeat
        Text_String=ReadString(CSV_File)
        Text_Data+Text_String+#LF$
      Until Eof(CSV_File)
      CloseFile(CSV_File)  
    EndIf

    Count=CountString(Text_Data,#LF$)
    
    For i=1 To count
      AddElement(Comp_Database())
      Text_Line=StringField(Text_Data,i,#LF$)
      Comp_Database()\C_Slave=LCase(StringField(Text_Line,1,";"))
      Comp_Database()\C_Folder=StringField(Text_Line,2,";")
      Comp_Database()\C_Genre=StringField(Text_Line,3,";")
      Comp_Database()\C_Name=StringField(Text_Line,4,";")
      Comp_Database()\C_Short=StringField(Text_Line,5,";")
    Next
    
  EndIf  
  
  SortStructuredList(UM_Database(),#PB_Sort_Ascending|#PB_Sort_NoCase,OffsetOf(UM_Data\UM_Name),TypeOf(UM_Data\UM_Name))
  
EndProcedure

Procedure Draw_List()
  
  Protected Text.s
  Protected Count
  
  Pause_Window(#MAIN_WINDOW)
  
  ClearGadgetItems(#MAIN_LIST)
  
  ClearList(Filtered_List())
  
  If filter Or unknown
    Filter_List()
  Else
    ForEach UM_Database()
      UM_Database()\UM_Filtered=#False
      AddElement(Filtered_List())
      Filtered_List()=ListIndex(UM_Database())
    Next
  EndIf

  ForEach Filtered_List()
    SelectElement(UM_Database(),Filtered_List())
    If Short_Names
      Text=UM_Database()\UM_Short+Chr(10)+UM_Database()\UM_Slave+Chr(10)+UM_Database()\UM_Path+Chr(10)+UM_Database()\UM_Genre
    Else
      Text=UM_Database()\UM_Name+Chr(10)+UM_Database()\UM_Slave+Chr(10)+UM_Database()\UM_Path+Chr(10)+UM_Database()\UM_Genre
    EndIf
    AddGadgetItem(#MAIN_LIST,-1,text)
    If ListIndex(UM_Database())>1
      If GetGadgetItemText(#MAIN_LIST, ListIndex(Filtered_List())-1,0)=UM_Database()\UM_Name
        SetGadgetItemColor(#MAIN_LIST, ListIndex(Filtered_List()), #PB_Gadget_FrontColor,#Red)
        SetGadgetItemColor(#MAIN_LIST, ListIndex(Filtered_List())-1, #PB_Gadget_FrontColor,#Red)
      EndIf
    EndIf 
    If UM_Database()\UM_Unknown=#True : SetGadgetItemColor(#MAIN_LIST, ListIndex(Filtered_List()), #PB_Gadget_FrontColor,#Blue) : EndIf
  Next
  
  For Count=0 To CountGadgetItems(#MAIN_LIST) Step 2
    SetGadgetItemColor(#MAIN_LIST,Count,#PB_Gadget_BackColor,$eeeeee)
  Next
  
  SetWindowTitle(#MAIN_WINDOW, "IGame Tool "+Version+" (Showing "+Str(CountGadgetItems(#MAIN_LIST))+" of "+Str(ListSize(UM_Database()))+" Games)")
  
  SetGadgetState(#MAIN_LIST,0)
  SetActiveGadget(#MAIN_LIST)
  
  If ListSize(Filtered_List())<>0
    DisableGadget(#TAG_BUTTON,#False)
  Else
    DisableGadget(#TAG_BUTTON,#True)
  EndIf
    
  Resume_Window(#MAIN_WINDOW)
  
EndProcedure

Procedure Fix_List()
  
  Backup_Database(#False)
  
  Message_Window("Fixing Game List...")
  
  Protected NewMap Comp_Map.i()
  
  Load_DB()
    
  ForEach Comp_Database()
    Comp_Map(LCase(Comp_Database()\C_Folder+"_"+Comp_Database()\C_Slave))=ListIndex(Comp_Database())
  Next
  
  ForEach UM_Database()
    If FindMapElement(Comp_Map(),LCase(UM_Database()\UM_Folder+"_"+UM_Database()\UM_Slave))
      SelectElement(Comp_Database(),Comp_Map())
      UM_Database()\UM_Name=Comp_Database()\C_Name
      UM_Database()\UM_Short=Comp_Database()\C_Short
      UM_Database()\UM_Genre=Comp_Database()\C_Genre
    EndIf
    If Not FindMapElement(Comp_Map(),LCase(UM_Database()\UM_Folder+"_"+UM_Database()\UM_Slave))
      UM_Database()\UM_Unknown=#True
    EndIf
  Next
  
  FreeMap(Comp_Map())
  ClearList(Comp_Database())
  
  SortStructuredList(UM_Database(),#PB_Sort_Ascending|#PB_Sort_NoCase,OffsetOf(UM_Data\UM_Name),TypeOf(UM_Data\UM_Name))
  
  DisableGadget(#SHORT_NAME_CHECK,#False)
  DisableGadget(#UNKNOWN_CHECK,#False)
  
  CloseWindow(#LOADING_WINDOW)
  
EndProcedure

Procedure Tag_List()
  
  Backup_Database(#False)
  
  Protected NewList Tags.i()
  Protected NewList Lines.i()
  
  Protected i, tag_entry.s
  
  For i=0 To CountGadgetItems(#MAIN_LIST)
    If GetGadgetItemState(#MAIN_LIST,i)=#PB_ListIcon_Selected
      SelectElement(Filtered_List(),i)
      SelectElement(UM_Database(),Filtered_List())
      AddElement(Tags())
      Tags()=ListIndex(UM_Database())
      AddElement(Lines())
      Lines()=i
    EndIf
  Next
  
  tag_entry=InputRequester("Add Tag", "Enter a new tag", "")
  
  If tag_entry<>""
    ForEach Tags()
      SelectElement(UM_Database(),Tags())
      UM_Database()\UM_Name=UM_Database()\UM_Name+" ("+tag_entry+")"
      SelectElement(Lines(),ListIndex(Tags()))
      SetGadgetItemText(#MAIN_LIST,Lines(),UM_Database()\UM_Name,0)
    Next
    ;Draw_List()
  EndIf
  
  FreeList(Tags())
  FreeList(Lines())
    
EndProcedure

Procedure Help_Window()
  
  Protected output$
  
  output$=""
  output$+"*** CAUTION ***"+Chr(10)
  output$+""+Chr(10)
  output$+"IGame Tool only supports CSV based game lists. You can tell if the list is right by the fact that it will be called 'gamelist.csv'. "
  output$+"If your game list doesn't have a '.csv' at the end of the file name then you have an older version of IGame."
  output$+" Please update it to the latest version at https://github.com/MrZammler/iGame/releases and rescan your repositories."+Chr(10)
  output$+""+Chr(10)
  output$+"*** About ***"+Chr(10)
  output$+""+Chr(10)
  output$+"IGame Tool is a small utility that uses a small database to improve the names and add game genres to Amiga IGame game list files. IGame Tool is not perfect and "
  output$+"isn't clever enough to find some files and will still duplicate some entries, but it is still better than the default list. There is some basic editing "
  output$+"that can be done to the entries to help repair any errors."+Chr(10)
  output$+""+Chr(10)
  output$+"*** Instructions ***"+Chr(10)
  output$+""+Chr(10)
  output$+"1. Copy the gameslist.csv file from your Amiga IGame drawer to your PC. Also... MAKE A BACKUP!"+Chr(10)
  output$+"2. Press the 'Load CSV' button to open your IGame game list."+Chr(10)
  output$+"3. Press the 'Fix List' button to fix the game names and add genres."+Chr(10)
  output$+"4. Make any other changes."+Chr(10)
  output$+"5. Press the 'Save CSV' button to save the new game list. You can overwrite the old game list or save as a new file."+Chr(10)
  output$+"6. Copy the new list and the supplied genres file back to the IGame drawer on your Amiga drive."+Chr(10)
  output$+""+Chr(10)
  output$+"*** Games List ***"+Chr(10)
  output$+""+Chr(10)
  output$+"Duplicate entries are highlighted in red and unknown entries are highlighted in blue. Missing entries will only be highlighted after you have pressed the 'Fix List' button."+Chr(10)
  output$+""+Chr(10)
  output$+"*** Editing ***"+Chr(10)
  output$+""+Chr(10)
  output$+"To edit a name, double click the entry on the list and change it's name in the new window."+Chr(10)
  output$+""+Chr(10)
  output$+"'Quick Tag' allows you can add multiple tags to the list entries. Just type the tag name into the new window and it will add it to the end of the game name."
  output$+" You can easily reduce any duplicate entries by using this button. Quick Tag will work with multiple selected entries. Use Ctrl or Shift when you click"
  output$+" the list to select multiple entries."+Chr(10)
  output$+""+Chr(10)
  output$+"'Undo' will reverse the last change that was made."+Chr(10)
  output$+""+Chr(10)
  output$+"*** Database ***"+Chr(10)
  output$+""+Chr(10)
  output$+"'Keep Data' keeps the play data from the original CSV file"+Chr(10)
  output$+""+Chr(10)
  output$+"'Use Short Names' replaces the game name with a 26 character short version."+Chr(10)
  output$+""+Chr(10)
  output$+"*** Filter ***"+Chr(10)
  output$+""+Chr(10)
  output$+"'Show Duplicates' filters the list and shows duplicate entries."+Chr(10)
  output$+""+Chr(10)
  output$+"'Show Unknown' filters the list and shows unknown entries. If an entry is marked as unknown, it may be worth checking to see it the slave has been updated."+Chr(10)
  
  If OpenWindow(#HELP_WINDOW,0,0,400,450,"Help",#PB_Window_SystemMenu|#PB_Window_WindowCentered,WindowID(#MAIN_WINDOW))
    EditorGadget(#HELP_EDITOR,0,0,400,450,#PB_Editor_ReadOnly|#PB_Editor_WordWrap)
    DestroyCaret_()
  EndIf
  
  If IsGadget(#HELP_EDITOR)
    SetGadgetText(#HELP_EDITOR,output$)
  EndIf
  
  SetActiveWindow(#HELP_WINDOW)
  
EndProcedure 

Procedure Edit_Window()
  
  Protected NewList Genres.s()
  
  If OpenFile(0,Home_Path+"genres")
    While Not Eof(0)
      AddElement(Genres())
      Genres()=ReadString(0)
    Wend
  Else
    MessageRequester("Error","Cannot Open Genres File!",#PB_MessageRequester_Error|#PB_MessageRequester_Ok)
    Goto Proc_Exit
  EndIf
  CloseFile(0)
  
  SortList(Genres(),#PB_Sort_Ascending) 
  
  Backup_Database(#False)
  
  If OpenWindow(#EDIT_WINDOW,0,0,300,125,"Edit",#PB_Window_SystemMenu|#PB_Window_WindowCentered,WindowID(#MAIN_WINDOW))
    
    TextGadget(#PB_Any,5,8,50,24,"Name",#PB_Text_Center)
    StringGadget(#EDIT_NAME,55,5,240,24,UM_Database()\UM_Name)
    
    TextGadget(#PB_Any,5,38,50,24,"Short",#PB_Text_Center)
    StringGadget(#EDIT_SHORT,55,35,240,24,UM_Database()\UM_Short)
    If UM_Database()\UM_Short="" : DisableGadget(#EDIT_SHORT,#True) : EndIf
    
    TextGadget(#PB_Any,5,68,50,24,"Slave",#PB_Text_Center)
    StringGadget(#EDIT_SLAVE,55,65,240,24,UM_Database()\UM_Slave)
    
    TextGadget(#PB_Any,5,98,50,24,"Genre",#PB_Text_Center)
    ComboBoxGadget(#EDIT_GENRE,55,95,240,24)
    
    ForEach Genres()
      AddGadgetItem(#EDIT_GENRE,-1,Genres())
    Next
    
    ForEach Genres()  
      If LCase(Genres())=LCase(UM_Database()\UM_Genre) 
        SetGadgetState(#EDIT_GENRE,ListIndex(Genres()))
        Break
      EndIf
    Next
    
  EndIf
  
  Proc_Exit:
  
  FreeList(Genres())
  
EndProcedure

Procedure Main_Window()

  If OpenWindow(#MAIN_WINDOW,0,0,900,600,"IGame Tool "+Version,#PB_Window_SystemMenu|#PB_Window_ScreenCentered)
    
    Pause_Window(#MAIN_WINDOW)
    
    ListIconGadget(#MAIN_LIST,0,0,900,550,"Name",240,#PB_ListIcon_GridLines|#PB_ListIcon_FullRowSelect|#PB_ListIcon_MultiSelect)
    SetGadgetColor(#MAIN_LIST,#PB_Gadget_BackColor,#White)
    AddGadgetColumn(#MAIN_LIST,1,"Slave",200)
    AddGadgetColumn(#MAIN_LIST,2,"Path",220)
    AddGadgetColumn(#MAIN_LIST,3,"Genre",220)

    ButtonGadget(#LOAD_BUTTON,5,555,80,40,"Load CSV")
    ButtonGadget(#FIX_BUTTON,90,555,80,40,"Fix List")
    ButtonGadget(#SAVE_BUTTON,175,555,80,40,"Save CSV")
    ButtonGadget(#TAG_BUTTON,260,555,80,40,"Quick Tag")
    ButtonGadget(#CLEAR_BUTTON,345,555,80,40,"Clear List")
    ButtonGadget(#UNDO_BUTTON,430,555,80,40,"Undo")
    ButtonGadget(#HELP_BUTTON,815,555,80,40,"Help")
    
    CheckBoxGadget(#KEEP_DATA_CHECK,515,553,85,25,"Keep Data")
    CheckBoxGadget(#SHORT_NAME_CHECK,515,573,85,25,"Short Names")
    CheckBoxGadget(#DUPE_CHECK,610,553,105,25,"Show Dupes")
    CheckBoxGadget(#UNKNOWN_CHECK,610,573,105,25,"Show Unknown")
    
    TextGadget(#PB_Any,720,554,90,22,"Output File")
    ComboBoxGadget(#CASE_COMBO,720,572,90,22)
    AddGadgetItem(#CASE_COMBO,-1,"Ignore Case")
    AddGadgetItem(#CASE_COMBO,-1,"Lower Case")
    AddGadgetItem(#CASE_COMBO,-1,"Upper Case")
    
    SetGadgetState(#CASE_COMBO,Output_Case)   
    SetGadgetState(#KEEP_DATA_CHECK,Keep_Data)
    SetGadgetState(#SHORT_NAME_CHECK,Short_Names)
    SetGadgetState(#DUPE_CHECK,Filter)
    
    DisableGadget(#FIX_BUTTON,#True)
    DisableGadget(#SAVE_BUTTON,#True)

    DisableGadget(#SHORT_NAME_CHECK,#True)
    DisableGadget(#KEEP_DATA_CHECK,#True)
    DisableGadget(#CLEAR_BUTTON,#True)
    DisableGadget(#UNKNOWN_CHECK,#True)
    DisableGadget(#DUPE_CHECK,#True)
    DisableGadget(#TAG_BUTTON,#True)
    DisableGadget(#UNDO_BUTTON,#True)
    DisableGadget(#CASE_COMBO,#True)
    
    Resume_Window(#MAIN_WINDOW)
    
  EndIf
  
EndProcedure

Main_Window()

Repeat
  
  event=WaitWindowEvent()
  gadget=EventGadget()
  
  Select event
      
    Case #PB_Event_CloseWindow
      If EventWindow()=#HELP_WINDOW
        CloseWindow(#HELP_WINDOW)
      EndIf
      If EventWindow()=#EDIT_WINDOW
        CloseWindow(#EDIT_WINDOW)
        Define Text.s
        If Short_Names
          Text=UM_Database()\UM_Short+Chr(10)+UM_Database()\UM_Slave+Chr(10)+UM_Database()\UM_Path+Chr(10)+UM_Database()\UM_Genre
        Else
          Text=UM_Database()\UM_Name+Chr(10)+UM_Database()\UM_Slave+Chr(10)+UM_Database()\UM_Path+Chr(10)+UM_Database()\UM_Genre
        EndIf
        SetGadgetItemText(#MAIN_LIST,GetGadgetState(#MAIN_LIST),Text)
      EndIf
      If EventWindow()=#MAIN_WINDOW
        If MessageRequester("Exit IGame Tool", "Do you want to quit?",#PB_MessageRequester_YesNo|#PB_MessageRequester_Warning)=#PB_MessageRequester_Yes
          close=#True
        EndIf  
      EndIf
            
      Case #PB_Event_Gadget
      
      Select gadget
          
        Case #LOAD_BUTTON
          If ListSize(UM_Database())>0
            ClearList(UM_Database())
            Pause_Window(#MAIN_WINDOW)
            ClearGadgetItems(#MAIN_LIST)
            Resume_Window(#MAIN_WINDOW)
          EndIf
          SetWindowTitle(#MAIN_WINDOW,"IGame Tool "+Version)
          Load_CSV()
          Draw_List()
          
        Case #SAVE_BUTTON
          Save_CSV()
          
        Case #UNDO_BUTTON
          If MessageRequester("Warning","Undo Last Change?",#PB_MessageRequester_Warning|#PB_MessageRequester_YesNo)=#PB_MessageRequester_Yes
            ClearList(UM_Database())
            CopyList(Undo_Database(),UM_Database())
            DisableGadget(#UNDO_BUTTON,#True)
            Draw_List()
          EndIf
          
        Case #FIX_BUTTON
          Fix_List()
          Draw_List()
          
        Case #TAG_BUTTON
          Tag_List()
                    
        Case #CLEAR_BUTTON
          If MessageRequester("Warning","Clear All Data?",#PB_MessageRequester_YesNo|#PB_MessageRequester_Warning)=#PB_MessageRequester_Yes
          FreeList(Undo_Database())
          FreeList(UM_Database())
          FreeList(Filtered_List())
          Pause_Window(#MAIN_WINDOW)
          ClearGadgetItems(#MAIN_LIST)
          DisableGadget(#FIX_BUTTON,#True)
          DisableGadget(#SAVE_BUTTON,#True)
          DisableGadget(#DUPE_CHECK,#True)
          DisableGadget(#SHORT_NAME_CHECK,#True)
          DisableGadget(#KEEP_DATA_CHECK,#True)
          DisableGadget(#CLEAR_BUTTON,#True)
          DisableGadget(#TAG_BUTTON,#True)
          DisableGadget(#UNKNOWN_CHECK,#True)
          DisableGadget(#UNDO_BUTTON,#True)
          DisableGadget(#CASE_COMBO,#True)
          Unknown=#False
          Filter=#False
          Short_Names=#False
          Output_Case=0
          SetGadgetState(#CASE_COMBO,Output_Case)
          SetGadgetState(#DUPE_CHECK,Filter)
          SetGadgetState(#UNKNOWN_CHECK,Unknown)
          SetGadgetState(#SHORT_NAME_CHECK,Short_Names)
          SetWindowTitle(#MAIN_WINDOW,"IGame Tool "+Version)
          Global NewList UM_Database.UM_Data()
          Global NewList Undo_Database.UM_Data()
          Global NewList Filtered_List.i()
          Resume_Window(#MAIN_WINDOW)
          EndIf
          
        Case #HELP_BUTTON
          Help_Window()
          
        Case #EDIT_NAME
          If EventType()=#PB_EventType_Change
            UM_Database()\UM_Name=GetGadgetText(#EDIT_NAME)
          EndIf
          
        Case #CASE_COMBO
          If EventType()=#PB_EventType_Change
            Output_Case=GetGadgetState(#CASE_COMBO)
          EndIf
          
        Case #EDIT_SHORT
          If EventType()=#PB_EventType_Change
            UM_Database()\UM_Short=GetGadgetText(#EDIT_SHORT)
          EndIf
          
       Case #EDIT_SLAVE
          If EventType()=#PB_EventType_Change
            UM_Database()\UM_Slave=GetGadgetText(#EDIT_SLAVE)
          EndIf   
          
        Case #EDIT_GENRE
          If EventType()=#PB_EventType_Change
            UM_Database()\UM_Genre=GetGadgetText(#EDIT_GENRE)
          EndIf 
          
        Case #SHORT_NAME_CHECK
          Short_Names=GetGadgetState(#SHORT_NAME_CHECK)
          If ListSize(UM_Database())>0
            Draw_List()
          EndIf
          
        Case #KEEP_DATA_CHECK
          Keep_Data=GetGadgetState(#KEEP_DATA_CHECK)
          
        Case #DUPE_CHECK
          Filter=GetGadgetState(#DUPE_CHECK)
          Draw_List()
          
        Case #UNKNOWN_CHECK
          Unknown=GetGadgetState(#UNKNOWN_CHECK)
          Draw_List()
          
        Case #MAIN_LIST
          If EventType()=#PB_EventType_LeftDoubleClick
            If ListSize(Filtered_List())>0
              SelectElement(Filtered_List(),GetGadgetState(#MAIN_LIST))
              SelectElement(UM_Database(),Filtered_List())
              Edit_Window()
            EndIf
            
          EndIf
          
      EndSelect
             
      
  EndSelect
  
Until close=#True

End
; IDE Options = PureBasic 6.00 Alpha 4 (Windows - x64)
; CursorPosition = 190
; FirstLine = 153
; Folding = 5-7
; Optimizer
; EnableThread
; EnableXP
; DPIAware
; UseIcon = boing.ico
; Executable = IGame_Tool_64.exe
; Compiler = PureBasic 6.00 Alpha 3 (Windows - x64)
; Debugger = Standalone
; IncludeVersionInfo
; VersionField0 = 0,0,0,2
; VersionField1 = 0,0,0,2
; VersionField2 = MrV2K
; VersionField3 = IGame Tool
; VersionField4 = 0.2 Alpha
; VersionField5 = 0.2 Alpha
; VersionField6 = IGame Conversion Tool
; VersionField7 = IG_Tool
; VersionField8 = IGame_Tool.exe
; VersionField9 = 2021 Paul Vince
; VersionField15 = VOS_NT
; VersionField16 = VFT_APP
; VersionField17 = 0809 English (United Kingdom)