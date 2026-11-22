; Project : Robot Warehouse Navigator
; Group : BCS-3E-10
; Leader : Vainkut Kumar (25K-0549)
; Member : Nitesh Kumar (25K-0631)
; Section : BCS-3E Instructor: Mr. Abdullah Shaikh
; Course : EL-2003 Computer Organization and Assembly Language Lab
; Univ. : FAST-NUCES Karachi Semester: Fall 2026
;
; Environment : 32-bit MASM, Irvine32 library, Visual Studio, Windows console
;
; Description : The robot starts at the entrance (top-left) of an 11 x 18
; warehouse and must collect a package [P] and bring it to the green
; destination [D], three times. Shelves are random obstacles; a flood fill
; makes sure every free tile can be reached. The robot '@' has a 2-character
; torch that turns with it (^@^ v@v <=@ @=>). A finished game is saved
; to robot_records.txt.
;
; Picture : if menu_bg.bmp is found (working directory, folder of the .exe, its
; parent or grandparent) it is shown behind every screen. The menu is a
; Win32 window; a second "mirror" window redraws the console text on top of
; the picture. If the picture is missing or a window cannot start, the game
; simply runs as a plain text console program.
;
; PARAMETER-PASSING CONVENTION
; Our own procedures take their inputs in REGISTERS (documented above each
; one) and return results in EAX or in the global variables named there.
; Only the Win32 callbacks and a few helpers use stdcall stack parameters
; (declared with PROTO below).
; Game state (robotRow, moveCount ...) lives in global variables.
; Every procedure PUSHes the registers it changes and POPs them again before
; RET, except the register that carries the return value.
;
; CONSOLE SIZE NEEDED : at least 103 columns x 28 rows (the default Windows
; console is 120 x 30, so this fits).

.386
.model flat, stdcall
.stack 16384
INCLUDE Irvine32.inc  ; also declares ExitProcess PROTO (stdcall)

; Windows API used by the picture menu window
; (If your Irvine32.inc already declares one of these, delete that PROTO line.)
INCLUDELIB user32.lib
INCLUDELIB gdi32.lib
GetConsoleWindow     PROTO
GetModuleHandleA     PROTO, lpModuleName:DWORD
GetModuleFileNameA   PROTO, hModule:DWORD, lpFilename:PTR BYTE, nSize:DWORD
GetCurrentDirectoryA PROTO, nBufferLength:DWORD, lpBuffer:PTR BYTE
GetProcAddress       PROTO, hModule:DWORD, lpProcName:PTR BYTE
LoadImageA           PROTO, hInst:DWORD, lpszName:PTR BYTE, uType:DWORD, cxDesired:DWORD, cyDesired:DWORD, fuLoad:DWORD
GetObjectA           PROTO, hObj:DWORD, cbBuffer:DWORD, lpvObject:PTR BYTE
RegisterClassExA     PROTO, lpwcx:DWORD
CreateWindowExA      PROTO, dwExStyle:DWORD, lpClassName:PTR BYTE, lpWindowName:PTR BYTE, dwStyle:DWORD, xPos:DWORD, yPos:DWORD, nWidth:DWORD, nHeight:DWORD, hWndParent:DWORD, hMenu:DWORD, hInstance:DWORD, lpParam:DWORD
DefWindowProcA       PROTO, hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
DestroyWindow        PROTO, hWnd:DWORD
PostQuitMessage      PROTO, nExitCode:DWORD
GetMessageA          PROTO, lpMsg:PTR DWORD, hWnd:DWORD, wMsgFilterMin:DWORD, wMsgFilterMax:DWORD
TranslateMessage     PROTO, lpMsg:PTR DWORD
DispatchMessageA     PROTO, lpMsg:PTR DWORD
ShowWindow           PROTO, hWnd:DWORD, nCmdShow:DWORD
UpdateWindow         PROTO, hWnd:DWORD
BeginPaint           PROTO, hWnd:DWORD, lpPaint:PTR DWORD
EndPaint             PROTO, hWnd:DWORD, lpPaint:PTR DWORD
InvalidateRect       PROTO, hWnd:DWORD, lpRect:DWORD, bErase:DWORD
LoadCursorA          PROTO, hInstance:DWORD, lpCursorName:DWORD
GetSystemMetrics     PROTO, nIndex:DWORD
AdjustWindowRect     PROTO, lpRect:PTR DWORD, dwStyle:DWORD, bMenu:DWORD
SetForegroundWindow  PROTO, hWnd:DWORD
SetFocus             PROTO, hWnd:DWORD
SwitchToThisWindow   PROTO, hWnd:DWORD, fAltTab:DWORD
GetAncestor          PROTO, hWnd:DWORD, gaFlags:DWORD
FillRect             PROTO, hDC:DWORD, lprc:PTR DWORD, hbr:DWORD
CreateCompatibleDC   PROTO, hdc:DWORD
CreateCompatibleBitmap PROTO, hdc:DWORD, nBmpW:DWORD, nBmpH:DWORD
SelectObject         PROTO, hdc:DWORD, hObj:DWORD
DeleteObject         PROTO, hObj:DWORD
DeleteDC             PROTO, hdc:DWORD
CreateSolidBrush     PROTO, crColor:DWORD
SetStretchBltMode    PROTO, hdc:DWORD, iMode:DWORD
StretchBlt           PROTO, hdcDest:DWORD, xDest:DWORD, yDest:DWORD, wDest:DWORD, hDest:DWORD, hdcSrc:DWORD, xSrc:DWORD, ySrc:DWORD, wSrc:DWORD, hSrc:DWORD, rop:DWORD
BitBlt               PROTO, hdcDest:DWORD, xDest:DWORD, yDest:DWORD, w:DWORD, h:DWORD, hdcSrc:DWORD, xSrc:DWORD, ySrc:DWORD, rop:DWORD
SetBkMode            PROTO, hdc:DWORD, iBkMode:DWORD
CreateFontA          PROTO, nHeight:DWORD, nWidth:DWORD, nEsc:DWORD, nOrient:DWORD, fnWeight:DWORD, fItalic:DWORD, fUnder:DWORD, fStrike:DWORD, fCharSet:DWORD, fOutPrec:DWORD, fClipPrec:DWORD, fQuality:DWORD, fPitch:DWORD, lpszFace:PTR BYTE
TextOutA             PROTO, hdc:DWORD, xStart:DWORD, yStart:DWORD, lpString:PTR BYTE, cbString:DWORD
; GDI's SetTextColor has the same name as the Irvine32 procedure, so it (and
; AlphaBlend) are fetched with GetProcAddress and called through a pointer.

GetDC                PROTO, hWnd:DWORD
ReleaseDC            PROTO, hWnd:DWORD, hDC:DWORD
SetTimer             PROTO, hWnd:DWORD, nIDEvent:DWORD, uElapse:DWORD, lpTimerFunc:DWORD
SetWindowPos         PROTO, hWnd:DWORD, hWndInsertAfter:DWORD, xPos:DWORD, yPos:DWORD, nW:DWORD, nH:DWORD, uFlags:DWORD
SendMessageA         PROTO, hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
TextOutW             PROTO, hdc:DWORD, xStart:DWORD, yStart:DWORD, lpString:PTR WORD, cbString:DWORD
; kernel32 console / thread functions are fetched with GetProcAddress (pointers)
; so they can never clash with prototypes inside Irvine32.inc / SmallWin.inc.

; procedures of this file that take stack parameters (need a prototype for INVOKE)
MirInjectKeyProc     PROTO, vk:DWORD, scan:DWORD, chr:DWORD
PaintMenuWindowProc  PROTO, hWnd:DWORD
FillBoxProc          PROTO, hdc:DWORD, xPos:DWORD, yPos:DWORD, wBox:DWORD, hBox:DWORD, color:DWORD
DrawLabelProc        PROTO, hdc:DWORD, xPos:DWORD, yPos:DWORD, pText:DWORD, color:DWORD, hFont:DWORD

; CONSTANTS (equates take no memory; the assembler replaces them by numbers)

; warehouse size
NUM_ROWS        = 11  ; rows 0..10 inside the program (1..11 on screen)
NUM_COLS        = 18  ; columns 0..17 inside the program (1..18 on screen)
GRID_SIZE       = NUM_ROWS * NUM_COLS  ; 198 bytes in the 2D array

; cell values stored in the warehouse array
CELL_PATH       = 0  ; walkable floor
CELL_SHELF      = 1  ; obstacle
CELL_DELIVERY   = 2  ; green delivery zone

; start position (zero-based): the entrance is the top-left cell
ROBOT_START_ROW = 0  ; displayed row 1
ROBOT_START_COL = 0  ; displayed column 1

; game rules and random-map settings
TOTAL_DELIVERIES = 3  ; packages to deliver to win
OBSTACLE_PERCENT = 22  ; chance (%) that a tile becomes a shelf
MIN_FREE_CELLS  = 80  ; a map with fewer reachable floor tiles is rejected
ROBOT_NAME_MAX  = 12  ; longest robot name
NAME_X          = 32  ; screen position of the name input field
NAME_Y          = 12
POLL_DELAY_MS   = 30  ; sleep between key polls (no redraw while idle)
RECORD_LEN      = 41  ; bytes per record line (39 text + CR + LF)
RECORD_TEXT_LEN = 39  ; visible characters of a record
RECORDS_MAX     = 8200  ; room for 200 records (200 * 41)
RECORDS_SHOWN   = 12  ; records listed on screen
FILE_INVALID    = -1  ; value Irvine32 file procedures return on error

; robot facing direction and torch
; facing = action code - 1, so ACT_UP..ACT_RIGHT (1..4) become 0..3
FACE_UP         = 0
FACE_DOWN       = 1
FACE_LEFT       = 2
FACE_RIGHT      = 3

; screen geometry (X = column, Y = row of the console)
CELL_W          = 3  ; every warehouse cell is 3 characters wide
GRID_W          = NUM_COLS * CELL_W  ; 54 characters of cells
GRID_X          = 3  ; screen X of the first cell
GRID_Y          = 4  ; screen Y of the first cell row
BORDER_L        = 2  ; screen X of the left border of the grid
BORDER_R        = GRID_X + GRID_W  ; 57 = screen X of the right border
SCREEN_W        = 103  ; width used by the header and action bars
PARK_Y          = 22  ; row where the cursor is parked

; sidebar geometry
SB_X            = 60  ; left edge of sidebar text
SB_VAL_X        = 81  ; X where the sidebar values start
SB_TITLE_Y      = 3
SB_SEP_Y        = 4
SB_NAME_Y       = 5
SB_POS_Y        = 6
SB_MOVE_Y       = 7
SB_DELIV_Y      = 8
SB_PKG_Y        = 9
SB_DEL_Y        = 10  ; destination status line
SB_DIR_Y        = 11  ; robot facing direction line
SB_SYS_Y        = 12
MSGBOX_TOP_Y    = 13
MSG_Y           = 14  ; row that holds the status message
MSGBOX_BOT_Y    = 15
MSG_W           = 42  ; inner width of the message box
SB_RESULT_Y     = 17
LEGEND_Y        = 17
BAR_Y           = 19  ; bottom action bar row

; menu box geometry
MENU_X          = 20
MENU_INNER_W    = 58

; action codes returned by ReadInputProc
ACT_NONE        = 0
ACT_UP          = 1
ACT_DOWN        = 2
ACT_LEFT        = 3
ACT_RIGHT       = 4
ACT_RESTART     = 5
ACT_INSTR       = 6
ACT_MENU        = 7
ACT_EXIT        = 8

; keyboard codes
KEY_ESC         = 1Bh
KEY_SC_UP       = 48h  ; scan codes (returned in AH for extended keys)
KEY_SC_DOWN     = 50h
KEY_SC_LEFT     = 4Bh
KEY_SC_RIGHT    = 4Dh
KEY_VK_LEFT     = 25h  ; Windows virtual-key codes (backup, in DX)
KEY_VK_UP       = 26h
KEY_VK_RIGHT    = 27h
KEY_VK_DOWN     = 28h

MAX_MOVES       = 999  ; counter is capped so it always has 3 digits

; colours: attribute = foreground + (background * 16)
COLOR_NORMAL    = lightGray + (black * 16)  ; the "reset" colour
COLOR_HEADER    = white     + (blue * 16)
COLOR_BAR       = black     + (lightGray * 16)
COLOR_LABEL     = yellow    + (black * 16)
COLOR_TITLE     = lightCyan + (black * 16)
COLOR_BORDER    = cyan      + (black * 16)
COLOR_INFO      = white     + (black * 16)
COLOR_OK        = lightGreen + (black * 16)  ; success messages
COLOR_WARN      = yellow    + (black * 16)  ; warning messages
COLOR_ERROR     = lightRed  + (black * 16)  ; error messages
TILE_PATH       = gray      + (lightGray * 16)  ; light-gray tile, dark dot
TILE_SHELF      = gray      + (black * 16)  ; dark-gray solid block
TILE_DELIVERY   = black     + (green * 16)  ; green highlighted tile
TILE_ROBOT      = black     + (cyan * 16)  ; robot body '@' on cyan
TILE_PACKAGE    = black     + (yellow * 16)  ; [P] on yellow

; torch colour (only the 2 torch characters use it)
TILE_TORCH      = yellow    + (blue * 16)  ; torch part of the robot glyph

; menu picture (GDI) constants
BG_IMAGE_BITMAP = 0  ; LoadImage type: bitmap
BG_LOAD_FROMFILE = 10h  ; LR_LOADFROMFILE: read the .bmp from disk
BG_ROP_COPY     = 00CC0020h  ; SRCCOPY
BG_HALFTONE     = 4  ; high-quality stretching mode

; picture menu window
WIN_W           = 1024  ; client size of the picture window (2:1 like menu_bg.bmp)
WIN_H           = 512
WIN_STYLE       = 10C80000h  ; WS_VISIBLE + WS_CAPTION + WS_SYSMENU (fixed size)
WIN_EXSTYLE     = 8  ; WS_EX_TOPMOST: always appears above the terminal
MW_DESTROY      = 2  ; window messages
MW_CLOSE        = 10h
MW_PAINT        = 0Fh
MW_ERASEBKGND   = 14h
MW_CHAR         = 102h
MW_MOUSEMOVE    = 200h
MW_LBUTTONDOWN  = 201h
PNL_X           = 36  ; translucent menu card inside the window
PNL_Y           = 30
PNL_W           = 470
PNL_H           = 452
OPT_X0          = PNL_X + 16  ; clickable option rows
OPT_X1          = PNL_X + PNL_W - 16
OPT_Y0          = PNL_Y + 196
OPT_STEP        = 54
OPT_H           = 46
BLEND_ALPHA     = 00BE0000h  ; BLENDFUNCTION: constant alpha 190 / 255
CLR_PANEL       = 00261208h  ; COLORREF = 00BBGGRR
CLR_TITLE       = 00FFEB78h
CLR_ACCENT      = 003296FFh
CLR_INFO        = 00E6C8AAh
CLR_WHITE       = 00FFFFFFh
CLR_HOVER_BG    = 0096641Eh
CLR_HOVER_TXT   = 0050DCFFh
CLR_HINT        = 005AD2FFh

; picture "mirror" window for the console screens
MIR_CW          = 9  ; pixel size of one console character cell
MIR_CH          = 18
MIR_MAXCOLS     = 150  ; largest console window that is mirrored
MIR_MAXROWS     = 40
MIR_MAXCELLS    = 6000  ; = MIR_MAXCOLS * MIR_MAXROWS
MIR_TIMER_MS    = 16  ; the console is checked about 60 times a second
MIR_STYLE       = 00C80000h  ; WS_CAPTION + WS_SYSMENU (not visible until shown)
MIR_DIM_ALPHA   = 00AA0000h  ; dark veil over the picture: alpha 170 / 255
MW_TIMER        = 113h
MW_KEYDOWN      = 100h
MW_RESET        = 401h  ; private message: show the plain picture again

; text-menu (fallback) panel geometry and colours
PANEL_X         = 2  ; left column of the menu panel
PANEL_Y         = 2  ; first row of the menu panel
PANEL_W         = 58  ; width in characters
PANEL_H         = 17  ; height in rows
MP_FILL         = white      + (blue * 16)  ; panel background
MP_BAND         = black      + (lightCyan * 16)  ; title band
MP_TEXT         = lightCyan  + (blue * 16)
MP_NAMES        = white      + (blue * 16)
MP_OPTION       = yellow     + (blue * 16)
MP_PROMPT       = lightGreen + (blue * 16)
MP_ERR          = white      + (red * 16)

.data

; MASTER WAREHOUSE TEMPLATE (blank floor, never changed while playing)
; 2D array of BYTEs in ROW-MAJOR order (row 0 first): 11 rows x 18 columns
; 198 bytes. 0 = path 1 = shelf 2 = delivery zone
; Random shelves, package and destination are added to the working copy by
; GenerateObstaclesProc / PlacePackageProc / PlaceDestinationProc.
masterWarehouse BYTE GRID_SIZE DUP(0)

; ACTIVE (working) warehouse grid: GRID_SIZE bytes, filled by InitWarehouseProc
warehouse       BYTE GRID_SIZE DUP(0)

; robot / package / movement state (DWORD = 4 bytes each)
robotRow        DWORD ROBOT_START_ROW
robotCol        DWORD ROBOT_START_COL
packageRow      DWORD 0  ; chosen randomly by PlacePackageProc
packageCol      DWORD 0
destRow         DWORD 0  ; chosen randomly by PlaceDestinationProc
destCol         DWORD 0
oldRow          DWORD ?  ; robot position before the move
oldCol          DWORD ?
proposedRow     SDWORD ?  ; SIGNED so that -1 can be detected
proposedCol     SDWORD ?

moveCount       DWORD 0
packageCollected DWORD 0  ; 0 = not collected, 1 = collected
deliveryComplete DWORD 0  ; 0 = game running,  1 = ALL deliveries done
deliveriesDone   DWORD 0  ; successful deliveries so far (0..3)
facing           DWORD FACE_RIGHT  ; direction the robot / torch points (0..3)
robotName        BYTE 16 DUP(0)  ; zero-terminated name typed by the player
robotNameLen     DWORD 0
saveOk           DWORD 0  ; 1 = record file written successfully

; what the sidebar shows (pointer to a string + its colour)
packageStatusPtr    DWORD ?
packageStatusColor  DWORD ?
deliveryStatusPtr   DWORD ?
deliveryStatusColor DWORD ?

; last system message (kept so a redraw can show it again)
curMsgPtr       DWORD ?
curMsgColor     DWORD ?

; scratch variables for loops (kept in memory so Irvine calls cannot
; disturb them)
cellRow         DWORD ?
cellCol         DWORD ?
gridRow         DWORD ?
gridCol         DWORD ?
loopIdx         DWORD ?
fillRow         DWORD ?  ; flood-fill work variables
fillCol         DWORD ?
queueHead       DWORD ?
queueTail       DWORD ?
recTotal        DWORD ?  ; records-screen work variables
recFirst        DWORD ?

; flood-fill tables
visited         BYTE GRID_SIZE DUP(0)  ; 1 = tile reached from the entrance
queueArr        DWORD GRID_SIZE DUP(0)  ; queue of tile offsets still to examine

; robot picture tables (index = facing 0..3 = UP, DOWN, LEFT, RIGHT)
; 4 x 3 robot pictures, one row per facing (3 characters = the 3-wide cell).
; ONE body character '@' + a 2-character torch that points the way it faces.
; The torch characters are marked 1 in robotTorchMap and use the torch colour.
robotGlyphs     BYTE '^','@','^'  ; UP    : torch ^ ^ above
                BYTE 'v','@','v'  ; DOWN  : torch v v below
                BYTE '<','=','@'  ; LEFT  : torch <= on the left
                BYTE '@','=','>'  ; RIGHT : torch => on the right
robotTorchMap   BYTE 1,0,1
                BYTE 1,0,1
                BYTE 1,1,0
                BYTE 0,1,1

; records file
recordFileName  BYTE "robot_records.txt",0
fileHandle      DWORD ?
recordsLen      DWORD 0  ; bytes currently held in recordsBuf
recordsBuf      BYTE (RECORDS_MAX + RECORD_LEN) DUP(0)
; one 41-byte record line, edited in place before it is saved:
; 0-11 name | 14 deliveries digit | 24-26 moves | 30-38 result | CR LF
recordLine      BYTE 12 DUP(' '), "  ", "3/3", "       ", "000", "   ", "Completed", 0Dh, 0Ah

; tile pictures (3 characters each; 0DBh, 0FAh, 0B1h are CP437 codes)
strPackage      BYTE "[P]",0
strPathTile     BYTE 20h,0FAh,20h,0  ; " . "
strShelfTile    BYTE 0DBh,0DBh,0DBh,0  ; solid block
strDeliveryTile BYTE "[D]",0  ; destination tile (green)

; screen text
strHeader       BYTE "Robot Warehouse Navigator - COAL Lab Project (BCS-3E-10)",0
strActionBar    BYTE "[Arrow Keys] Move | [R] Restart | [I] Instructions | [M] Main Menu | [Q / ESC] Exit",0
strSbTitle      BYTE "ROBOT DASHBOARD - LIVE TELEMETRY",0
strSbName       BYTE "ROBOT NAME:",0
strSbPos        BYTE "POSITION:",0
strSbMove       BYTE "MOVE COUNT:",0
strSbDeliv      BYTE "DELIVERIES:",0
strSbPackage    BYTE "PACKAGE STATUS:",0
strSbDelivery   BYTE "DESTINATION STATUS:",0
strSbDir        BYTE "DIRECTION:",0
strDirUp        BYTE "UP (^)   ",0
strDirDown      BYTE "DOWN (v) ",0
strDirLeft      BYTE "LEFT (<) ",0
strDirRight     BYTE "RIGHT (>)",0
dirNamePtrs     DWORD OFFSET strDirUp, OFFSET strDirDown, OFFSET strDirLeft, OFFSET strDirRight
strSbSystem     BYTE "SYSTEM STATUS:",0
strPosRow       BYTE "Row ",0
strPosCol       BYTE ", Col ",0
strSpaces3      BYTE "   ",0
strSlashTotal   BYTE "/3",0
strBlankMsg     BYTE MSG_W DUP(' '),0  ; 42 spaces used to erase a line
strResultPrefix BYTE "Delivered in ",0
strResultSuffix BYTE " moves!",0

; status words (padded so a shorter word fully erases a longer one)
strPkgPending     BYTE "Pending  ",0
strPkgCollected   BYTE "Collected",0
strPkgDelivered   BYTE "Delivered",0
strDestWaiting    BYTE "Waiting  ",0
strDestActive     BYTE "ACTIVE   ",0
strDestReached    BYTE "Reached  ",0

; system messages
strMsgReady       BYTE "Robot ready. Use arrow keys to move.",0
strMsgBlocked     BYTE "Blocked! Shelf obstacle ahead.",0
strMsgBoundary    BYTE "Invalid move! Boundary reached.",0
strMsgCollected   BYTE "Package collected! Head to green zone.",0
strMsgNeedPackage BYTE "Collect the package [P] before delivering!",0
strMsgDelivered   BYTE "All 3 deliveries done! Mission complete!",0
strMsgDeliveredN  BYTE "Delivery X of 3 complete! New package set.",0  ; X patched at run time

; legend shown under the grid
strLegRobot     BYTE " Robot   ",0
strLegPackage   BYTE " Package   ",0
strLegShelf     BYTE " Shelf   ",0
strLegDelivery  BYTE " Destination",0

; main menu text
strMenuTitle    BYTE "ROBOT WAREHOUSE NAVIGATOR",0
strMenuLine1    BYTE "COAL Lab Semester Project - Fall 2026",0
strMenuLine2    BYTE "Group BCS-3E-10 | FAST-NUCES Karachi",0
strMenuLine3    BYTE "Vainkut Kumar (25K-0549)  |  Nitesh Kumar (25K-0631)",0
strMenuLine4    BYTE "Instructor: Mr. Abdullah Shaikh",0
strMenuOpt1     BYTE "1.  Start Game",0
strMenuOpt2     BYTE "2.  Instructions",0
strMenuOpt3     BYTE "3.  Previous Records",0
strMenuOpt4     BYTE "4.  Exit",0
strMenuPrompt   BYTE "Enter your choice (1-4):",0
strMenuInvalid  BYTE "Invalid choice! Please press 1, 2, 3 or 4.",0

; instructions screen text
strInsTitle     BYTE "INSTRUCTIONS AND CONTROLS",0
strInsH1        BYTE "PROJECT OBJECTIVE",0
strInsT1        BYTE "  Deliver 3 packages. Each delivery creates the next package. Press R for a new random map.",0
strInsH2        BYTE "HOW TO COLLECT THE PACKAGE",0
strInsT2a       BYTE "  Move the robot (@) onto the yellow [P] tile. The package is collected automatically",0
strInsT2b       BYTE "  and disappears from the grid. Destination status then changes to ACTIVE.",0
strInsH3        BYTE "HOW TO REACH THE DESTINATION",0
strInsT3a       BYTE "  After collecting the package, step onto the green [D] tile to complete the delivery.",0
strInsT3b       BYTE "  Entering [D] without the package does nothing. After delivery 3 the record is saved.",0
strInsT3c       BYTE "  The robot turns toward the arrow key you press; its 2-character torch shows the direction.",0
strInsH4        BYTE "GRID LEGEND",0
strInsRobot     BYTE "= Robot (@) with a 2-character torch (^ v <= => shows where it faces)",0
strInsPackage   BYTE "= Package to collect",0
strInsShelf     BYTE "= Shelf / obstacle (blocked)",0
strInsPath      BYTE "= Walkable path",0
strInsDelivery  BYTE "= Green destination tile (deliver here)",0
strInsH5        BYTE "CONTROLS",0
strInsC1        BYTE "  [Arrow Keys] Move the robot (Up, Down, Left, Right)",0
strInsC2        BYTE "  [R] Restart   [I] Instructions   [M] Main Menu   [Q] or [ESC] Exit",0
strInsC3        BYTE "  Shelves and the warehouse boundary block the robot; blocked moves are not counted.",0
strInsBack      BYTE "Press any key to go back...",0

; robot-name screen
strNameTitle    BYTE "ENTER ROBOT NAME",0
strNamePrompt   BYTE "Name your robot (up to 12 characters), then press ENTER:",0
strNameHint     BYTE "Leave it empty for the default name ROBO-1.  Backspace erases.",0
strNameArrow    BYTE "> ",0
strDefaultName  BYTE "ROBO-1",0

; final results screen
strResTitle     BYTE "MISSION COMPLETE!",0
strResName      BYTE "Robot Name  :",0
strResDeliv     BYTE "Deliveries  :",0
strResMoves     BYTE "Total Moves :",0
strResResult    BYTE "Result      :",0
strResDone      BYTE "Completed",0
strResSaved     BYTE "Record saved to robot_records.txt",0
strResNotSaved  BYTE "Warning: could not save the record file.",0
strResKeys      BYTE "[R] Play Again    [M] Main Menu    [Q / ESC] Exit",0

; previous-records screen
strRecTitle     BYTE "PREVIOUS RECORDS",0
strRecHeader    BYTE "  No.  Robot Name    Delivered Moves Result",0
strRecNone      BYTE "No previous records found. Complete a game to create one.",0
strRecNote      BYTE "Most recent records shown (max 12). File: robot_records.txt",0

; picture menu data
bgFileName      BYTE "menu_bg.bmp",0  ; (1) working directory
bgSuffix0       BYTE "menu_bg.bmp",0  ; (2) <exe folder>\menu_bg.bmp
bgSuffix1       BYTE "..\menu_bg.bmp",0  ; (3) parent of the exe folder
bgSuffix2       BYTE "..\..\menu_bg.bmp",0  ; (4) grandparent of the exe folder
exeDir          BYTE 300 DUP(0)  ; folder of the .exe, ends with a backslash
cwdBuf          BYTE 300 DUP(0)  ; current working directory
pathBuf         BYTE 620 DUP(0)  ; candidate full path being tried
hBgBitmap       DWORD 0  ; HBITMAP of the picture (0 = not loaded)
bmpInfo         DWORD 6 DUP(0)  ; BITMAP structure: +4 = width, +8 = height

szClassName     BYTE "RobotWarehouseMenuWnd",0
szWndTitle      BYTE "Robot Warehouse Navigator - Main Menu",0
szFontName      BYTE "Segoe UI",0
szGdi32         BYTE "gdi32.dll",0
szSetTextColor  BYTE "SetTextColor",0
szAlphaBlend    BYTE "GdiAlphaBlend",0
strMenuHint     BYTE "Press 1-4 or click an option     |     ESC = Exit",0
pSetTextColor   DWORD 0  ; GDI SetTextColor (by pointer)
pAlphaBlend     DWORD 0  ; GDI AlphaBlend   (by pointer)
classRegistered DWORD 0
hInst           DWORD 0
hFontTitle      DWORD 0
hFontOpt        DWORD 0
hFontSmall      DWORD 0
menuChoice      DWORD 0  ; 1..4 chosen in the picture window
hoverIdx        SDWORD -1  ; option under the mouse (-1 = none)
winW            DWORD 0
winH            DWORD 0
wcBuf           DWORD 12 DUP(0)  ; WNDCLASSEX
msgBuf          DWORD 7 DUP(0)  ; MSG
psBuf           DWORD 16 DUP(0)  ; PAINTSTRUCT
rcWin           DWORD 4 DUP(0)  ; RECT used by AdjustWindowRect
tmpRect         DWORD 4 DUP(0)  ; RECT used by FillBoxProc
optionTable     DWORD OFFSET strMenuOpt1, OFFSET strMenuOpt2, OFFSET strMenuOpt3, OFFSET strMenuOpt4
strNoImg1       BYTE "Picture menu_bg.bmp was NOT found, so the text menu is shown.  Folders searched:",0
strNoImg2       BYTE "  Working directory : ",0
strNoImg3       BYTE "  Program folder    : ",0
strNoImg4       BYTE "  (also the parent and grandparent of the program folder)",0
; mirror window data
szKernel32      BYTE "kernel32.dll",0
szGetStdHandle  BYTE "GetStdHandle",0
szGetCsbi       BYTE "GetConsoleScreenBufferInfo",0
szReadOutW      BYTE "ReadConsoleOutputW",0
szWriteInA      BYTE "WriteConsoleInputA",0
szCreateThread  BYTE "CreateThread",0
szMirClass      BYTE "RobotWarehouseMirrorWnd",0
szMirTitle      BYTE "Robot Warehouse Navigator",0
szMirFont       BYTE "Consolas",0
pGetStdHandle   DWORD 0
pGetCsbi        DWORD 0
pReadOutW       DWORD 0
pWriteInA       DWORD 0
pCreateThread   DWORD 0
hOutCon         DWORD 0  ; console output handle
hInCon          DWORD 0  ; console input handle
hMirWnd         DWORD 0  ; the mirror window (0 = not created yet)
hMirThread      DWORD 0
mirThreadId     DWORD 0
mirrorFailed    DWORD 0  ; 1 = mirror could not start -> plain console
mirActive       DWORD 0  ; 1 while the mirror window is in use
mirForce        DWORD 1  ; 1 = draw the next stable frame even if unchanged
showCaret       DWORD 0  ; 1 = draw a text caret (name entry screen)
mirCols         DWORD 120
mirRows         DWORD 30
mirCells        DWORD 3600
mirLeft         DWORD 0
mirTop          DWORD 0
mirWinW         DWORD 1080
mirWinH         DWORD 540
mirOuterW       DWORD 0
mirOuterH       DWORD 0
hMirFrameDC     DWORD 0  ; off-screen frame that is copied to the window
hMirFrameBmp    DWORD 0
hMirBgDC        DWORD 0  ; dimmed picture
hMirBgBmp       DWORD 0
mChar           DWORD 0  ; work variables of MirrorDrawFrameProc
mFg             DWORD 0
mBg             DWORD 0
mX              DWORD 0
mY              DWORD 0
lastFg          SDWORD -1
mirWc           DWORD 12 DUP(0)  ; WNDCLASSEX of the mirror
mirMsg          DWORD 7 DUP(0)  ; MSG of the mirror thread
mirPs           DWORD 16 DUP(0)  ; PAINTSTRUCT of the mirror
mirRect         DWORD 4 DUP(0)
rcMirAdj        DWORD 4 DUP(0)
csbiBuf         DWORD 6 DUP(0)  ; CONSOLE_SCREEN_BUFFER_INFO (22 bytes)
readRegion      DWORD 2 DUP(0)  ; SMALL_RECT (4 WORDs)
inRec           DWORD 5 DUP(0)  ; INPUT_RECORD (20 bytes)
inWritten       DWORD 0
mirBrush        DWORD 16 DUP(0)  ; one solid brush per console colour
mirPalette      DWORD 00C0C0Ch, 0DA3700h, 00EA113h, 0DD963Ah, 01F0FC5h, 0981788h, 0009CC1h, 0CCCCCCh, 0767676h, 0FF783Bh, 00CC616h, 0D6D661h, 05648E7h, 09E00B4h, 03BEBFFh, 0F2F2F2h
mirCur          DWORD (MIR_MAXCELLS + 1) DUP(0)  ; last read console cells (+1 = caret)
mirPrev         DWORD (MIR_MAXCELLS + 1) DUP(0)  ; the read before (stability test)
mirShown        DWORD (MIR_MAXCELLS + 1) DUP(0)  ; what is on screen now
strWinFail      BYTE "The picture window could not be opened - using the text menu.",0

.code

; main : program entry point. Shows the menu; ExitProc ends the program.
main PROC
    call Randomize  ; Irvine32: seed the random generator ONCE
    call LoadMenuImageProc
    call MainMenuProc
    INVOKE ExitProcess, 0  ; stdcall: pushes 0 then calls ExitProcess
main ENDP

; GROUP A - UI AND GRID PROCEDURES

; PrintAtProc (small helper)
; Receives : DL = screen X, DH = screen Y, ESI = OFFSET of a 0-terminated string
; Returns : nothing. Prints the string at that position in the CURRENT colour.
; Preserves: all registers (EDX is saved because we overwrite it for WriteString)
PrintAtProc PROC
    push edx
    call Gotoxy  ; Irvine32: move cursor to column DL, row DH
    mov edx, esi
    call WriteString
    pop edx
    ret
PrintAtProc ENDP

; RepeatCharProc (small helper)
; Receives : AL = character, ECX = how many times (must be 1 or more)
; Returns : nothing. Writes the character ECX times at the cursor.
; Preserves: ECX (pushed/popped because LOOP destroys it)
RepeatCharProc PROC
    push ecx
RepeatLoop:
    call WriteChar  ; Irvine32: print the character in AL
    loop RepeatLoop
    pop ecx
    ret
RepeatCharProc ENDP

; ParkCursorProc (small helper)
; Moves the blinking cursor to an empty spot below the interface.
; Receives : nothing Returns : nothing Preserves : all registers
ParkCursorProc PROC
    push edx
    mov dl, 0
    mov dh, PARK_Y
    call Gotoxy
    pop edx
    ret
ParkCursorProc ENDP

; WriteThreeDigitsProc (formatting procedure for the move counter)
; WriteDec never prints leading zeros, so we print the zeros ourselves.
; Receives : EAX = number 0..999
; Returns : nothing. Prints exactly three digits, e.g. 000, 007, 045, 125.
; Preserves: all registers
WriteThreeDigitsProc PROC
    push eax
    cmp eax, 99
    jg PrintNumber
    push eax
    mov al, '0'
    call WriteChar
    pop eax
    cmp eax, 9
    jg PrintNumber
    push eax
    mov al, '0'
    call WriteChar
    pop eax
PrintNumber:
    call WriteDec  ; Irvine32: print unsigned decimal in EAX
    pop eax
    ret
WriteThreeDigitsProc ENDP

; MainMenuProc
; Shows the picture menu (or the text menu if the picture is missing) and starts
; the chosen option: 1 = game, 2 = instructions, 3 = records, 4 = exit.
; Receives : nothing Returns : nothing (option 4 ends the program)
MainMenuProc PROC
    push eax
    push ebx
    push ecx
    push edx
    push esi

MenuRedraw:
    mov eax, COLOR_NORMAL
    call SetTextColor
    call Clrscr
    call MirrorHideProc
    call ShowPictureMenuProc
    test eax, eax
    jz MenuPicUnavailable
    cmp eax, 4
    je MenuExit
    push eax
    call MirrorShowProc
    pop eax
    cmp eax, 1
    je MenuStart
    cmp eax, 2
    je MenuInstructions
    jmp MenuRecords

MenuPicUnavailable:
    mov eax, 5
    call SetConsoleVisProc
    call DrawMenuPanelProc
    cmp hBgBitmap, 0
    je MenuReadKey
    mov eax, COLOR_WARN
    call SetTextColor
    mov dl, 2
    mov dh, 21
    mov esi, OFFSET strWinFail
    call PrintAtProc

MenuReadKey:
    call ReadChar
    cmp al, '1'
    je MenuStart
    cmp al, '2'
    je MenuInstructions
    cmp al, '3'
    je MenuRecords
    cmp al, '4'
    je MenuExit

    ; any other key = invalid choice -> show an error and wait again
    mov eax, MP_ERR
    call SetTextColor
    mov dl, 12
    mov dh, 16
    mov esi, OFFSET strMenuInvalid
    call PrintAtProc
    jmp MenuReadKey

MenuStart:
    call NameEntryProc
    call InitWarehouseProc
    call GameLoopProc
    jmp MenuRedraw

MenuInstructions:
    call ShowInstructionsProc
    jmp MenuRedraw

MenuRecords:
    call ShowRecordsProc
    jmp MenuRedraw

MenuExit:
    call ExitProc

    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
MainMenuProc ENDP

; FillRectProc (helper)
; Fills a rectangle with blank characters in one colour (a solid colour block).
; Receives : EAX = colour attribute, DL = left X, DH = top Y,
; EBX = number of rows, ECX = width in characters
; Returns : nothing Preserves: all registers
FillRectProc PROC
    push eax
    push ebx
    push edx

    call SetTextColor
FillRectRow:
    call Gotoxy
    mov al, ' '
    call RepeatCharProc
    inc dh
    dec ebx
    jnz FillRectRow

    pop edx
    pop ebx
    pop eax
    ret
FillRectProc ENDP

; DrawMenuPanelProc
; Draws the readable part of the menu on top of the picture: one solid blue
; panel, a cyan title band, the project information, the four options and the
; prompt. Everything is plain text on solid colour (no line-drawing art).
; Receives : nothing Returns : nothing Preserves: all registers
DrawMenuPanelProc PROC
    push eax
    push ebx
    push ecx
    push edx
    push esi

    ; solid panel, then the title band over its first three rows
    mov eax, MP_FILL
    mov dl, PANEL_X
    mov dh, PANEL_Y
    mov ebx, PANEL_H
    mov ecx, PANEL_W
    call FillRectProc
    mov eax, MP_BAND
    mov dl, PANEL_X
    mov dh, PANEL_Y
    mov ebx, 3
    mov ecx, PANEL_W
    call FillRectProc

    ; title (on the band)
    mov eax, MP_BAND
    call SetTextColor
    mov dl, 18
    mov dh, 3
    mov esi, OFFSET strMenuTitle
    call PrintAtProc

    ; project information
    mov eax, MP_TEXT
    call SetTextColor
    mov dl, 12
    mov dh, 5
    mov esi, OFFSET strMenuLine1
    call PrintAtProc
    mov dl, 13
    mov dh, 6
    mov esi, OFFSET strMenuLine2
    call PrintAtProc
    mov eax, MP_NAMES
    call SetTextColor
    mov dl, 5
    mov dh, 7
    mov esi, OFFSET strMenuLine3
    call PrintAtProc
    mov eax, MP_TEXT
    call SetTextColor
    mov dl, 15
    mov dh, 8
    mov esi, OFFSET strMenuLine4
    call PrintAtProc

    ; the four options
    mov eax, MP_OPTION
    call SetTextColor
    mov dl, 19
    mov dh, 10
    mov esi, OFFSET strMenuOpt1
    call PrintAtProc
    mov dl, 19
    mov dh, 11
    mov esi, OFFSET strMenuOpt2
    call PrintAtProc
    mov dl, 19
    mov dh, 12
    mov esi, OFFSET strMenuOpt3
    call PrintAtProc
    mov dl, 19
    mov dh, 13
    mov esi, OFFSET strMenuOpt4
    call PrintAtProc

    ; prompt
    mov eax, MP_PROMPT
    call SetTextColor
    mov dl, 19
    mov dh, 15
    mov esi, OFFSET strMenuPrompt
    call PrintAtProc

    ; picture missing: say exactly which folders were searched
    cmp hBgBitmap, 0
    jne MenuPanelDone
    mov eax, COLOR_WARN
    call SetTextColor
    mov dl, 2
    mov dh, 19
    mov esi, OFFSET strNoImg1
    call PrintAtProc
    mov dl, 2
    mov dh, 20
    mov esi, OFFSET strNoImg2
    call PrintAtProc
    mov edx, OFFSET cwdBuf
    call WriteString
    mov dl, 2
    mov dh, 21
    mov esi, OFFSET strNoImg3
    call PrintAtProc
    mov edx, OFFSET exeDir
    call WriteString
    mov dl, 2
    mov dh, 22
    mov esi, OFFSET strNoImg4
    call PrintAtProc
MenuPanelDone:
    mov eax, COLOR_NORMAL
    call SetTextColor

    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
DrawMenuPanelProc ENDP

; TryLoadPathProc (helper)
; Receives : ESI = address of a 0-terminated file name / path
; Returns : EAX = HBITMAP, or 0 if that file cannot be loaded
; Preserves: everything except EAX
TryLoadPathProc PROC
    push ecx
    push edx
    INVOKE LoadImageA, 0, esi, BG_IMAGE_BITMAP, 0, 0, BG_LOAD_FROMFILE
    pop edx
    pop ecx
    ret
TryLoadPathProc ENDP

; TryLoadInExeDirProc (helper)
; Builds <exe folder> + suffix in pathBuf and tries to load it.
; Receives : ESI = address of the suffix (for example "..\menu_bg.bmp")
; Returns : EAX = HBITMAP, or 0 Preserves: everything except EAX
TryLoadInExeDirProc PROC
    push ebx
    push ecx
    push edx
    push esi
    push edi

    mov edi, OFFSET pathBuf
    mov ebx, OFFSET exeDir
CopyDirLoop:
    mov al, [ebx]
    cmp al, 0
    je CopyDirDone
    mov [edi], al
    inc ebx
    inc edi
    jmp CopyDirLoop
CopyDirDone:
AppendSuffixLoop:
    mov al, [esi]  ; append the suffix including its 0 terminator
    mov [edi], al
    inc esi
    inc edi
    cmp al, 0
    jne AppendSuffixLoop
    mov esi, OFFSET pathBuf
    call TryLoadPathProc

    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
TryLoadInExeDirProc ENDP

; LoadMenuImageProc
; Loads menu_bg.bmp (called once when the program starts). Search order:
; 1. menu_bg.bmp in the current working directory
; 2. <exe folder>\menu_bg.bmp (double-clicking the .exe)
; 3. <exe folder>\..\menu_bg.bmp (exe in Debug\, picture in the project)
; 4. <exe folder>\..\..\menu_bg.bmp
; LoadImage with LR_LOADFROMFILE reads .bmp files only (not PNG / JPG).
; Returns : hBgBitmap = bitmap handle (0 = not found); bmpInfo = its size;
; cwdBuf / exeDir = the folders searched (shown if nothing is found)
; Preserves: all registers
LoadMenuImageProc PROC
    push eax
    push ebx
    push ecx
    push edx
    push esi

    mov hBgBitmap, 0
    mov BYTE PTR cwdBuf, 0
    mov BYTE PTR exeDir, 0
    INVOKE GetCurrentDirectoryA, 260, OFFSET cwdBuf
    INVOKE GetModuleFileNameA, 0, OFFSET exeDir, 260
    mov ecx, eax
    mov esi, OFFSET exeDir
CutNameLoop:
    cmp ecx, 0
    je CutNameDone
    cmp BYTE PTR [esi + ecx - 1], '\'
    je CutNameDone
    dec ecx
    jmp CutNameLoop
CutNameDone:
    mov BYTE PTR [esi + ecx], 0

    mov esi, OFFSET bgFileName
    call TryLoadPathProc
    test eax, eax
    jnz LoadFound
    mov esi, OFFSET bgSuffix0
    call TryLoadInExeDirProc
    test eax, eax
    jnz LoadFound
    mov esi, OFFSET bgSuffix1
    call TryLoadInExeDirProc
    test eax, eax
    jnz LoadFound
    mov esi, OFFSET bgSuffix2
    call TryLoadInExeDirProc
    test eax, eax
    jz LoadImgDone

LoadFound:
    mov hBgBitmap, eax
    INVOKE GetObjectA, hBgBitmap, 24, OFFSET bmpInfo
    test eax, eax
    jnz LoadImgDone
    mov hBgBitmap, 0
LoadImgDone:
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
LoadMenuImageProc ENDP

; HitTestProc (helper of the picture window)
; Receives : EAX = mouse X, EDX = mouse Y (client coordinates)
; Returns : EAX = option index 0..3, or -1 if the mouse is not over an option
; Preserves: everything except EAX and EDX
HitTestProc PROC
    push ecx
    cmp eax, OPT_X0
    jl HitMiss  ; JL (signed): left of the option rows
    cmp eax, OPT_X1
    jge HitMiss
    sub edx, OPT_Y0
    jl HitMiss
    mov eax, edx
    xor edx, edx
    mov ecx, OPT_STEP
    div ecx
    cmp eax, 3
    ja HitMiss
    cmp edx, OPT_H
    jae HitMiss
    jmp HitDone
HitMiss:
    mov eax, -1
HitDone:
    pop ecx
    ret
HitTestProc ENDP

; FillBoxProc (stdcall parameters on the stack)
; Fills a rectangle of a device context with one colour (COLORREF 00BBGGRR).
FillBoxProc PROC USES ebx esi edi, hdc:DWORD, xPos:DWORD, yPos:DWORD, wBox:DWORD, hBox:DWORD, color:DWORD
    mov eax, xPos
    mov tmpRect[0], eax
    add eax, wBox
    mov tmpRect[8], eax
    mov eax, yPos
    mov tmpRect[4], eax
    add eax, hBox
    mov tmpRect[12], eax
    INVOKE CreateSolidBrush, color
    mov ebx, eax
    INVOKE FillRect, hdc, OFFSET tmpRect, ebx
    INVOKE DeleteObject, ebx
    ret
FillBoxProc ENDP

; DrawLabelProc (stdcall parameters on the stack)
; Draws a 0-terminated string at (xPos, yPos) with a font and a text colour.
; GDI SetTextColor is called through pSetTextColor (see the prototypes note).
DrawLabelProc PROC USES ebx esi edi, hdc:DWORD, xPos:DWORD, yPos:DWORD, pText:DWORD, color:DWORD, hFont:DWORD
    INVOKE SelectObject, hdc, hFont
    cmp pSetTextColor, 0
    je LabelNoColor
    push color  ; SetTextColor(hdc, color)  - stdcall, 2 parameters
    push hdc
    call pSetTextColor
LabelNoColor:
    INVOKE Str_length, pText  ; Irvine32: EAX = length of the string
    INVOKE TextOutA, hdc, xPos, yPos, pText, eax
    ret
DrawLabelProc ENDP

; PaintMenuWindowProc (WM_PAINT)
; Draws everything into an off-screen bitmap first and copies it to the window
; in ONE step, so the window never flickers:
; picture (StretchBlt) -> translucent dark card (AlphaBlend) -> title,
; project info, the four options (hover highlighted) and the hint line.
PaintMenuWindowProc PROC USES ebx esi edi, hWnd:DWORD
    LOCAL hdcWin:DWORD, hdcBack:DWORD, hBackBmp:DWORD, hOldBack:DWORD
    LOCAL hMem:DWORD, hOldMem:DWORD
    LOCAL hPanelDC:DWORD, hPanelBmp:DWORD, hOldPanel:DWORD

    INVOKE BeginPaint, hWnd, OFFSET psBuf
    mov hdcWin, eax
    INVOKE CreateCompatibleDC, hdcWin
    mov hdcBack, eax
    INVOKE CreateCompatibleBitmap, hdcWin, WIN_W, WIN_H
    mov hBackBmp, eax
    INVOKE SelectObject, hdcBack, hBackBmp
    mov hOldBack, eax

    ; 1) the picture, stretched over the whole window
    INVOKE CreateCompatibleDC, hdcWin
    mov hMem, eax
    INVOKE SelectObject, hMem, hBgBitmap
    mov hOldMem, eax
    INVOKE SetStretchBltMode, hdcBack, BG_HALFTONE
    INVOKE StretchBlt, hdcBack, 0, 0, WIN_W, WIN_H, hMem, 0, 0, bmpInfo[4], bmpInfo[8], BG_ROP_COPY
    INVOKE SelectObject, hMem, hOldMem
    INVOKE DeleteDC, hMem

    ; 2) translucent dark card behind the text (opaque if AlphaBlend is missing)
    INVOKE CreateCompatibleDC, hdcWin
    mov hPanelDC, eax
    INVOKE CreateCompatibleBitmap, hdcWin, PNL_W, PNL_H
    mov hPanelBmp, eax
    INVOKE SelectObject, hPanelDC, hPanelBmp
    mov hOldPanel, eax
    INVOKE FillBoxProc, hPanelDC, 0, 0, PNL_W, PNL_H, CLR_PANEL
    cmp pAlphaBlend, 0
    je PaintCardOpaque
    push BLEND_ALPHA  ; AlphaBlend(hdcBack, PNL_X, PNL_Y, PNL_W, PNL_H,
    push PNL_H
    push PNL_W
    push 0
    push 0
    push hPanelDC
    push PNL_H
    push PNL_W
    push PNL_Y
    push PNL_X
    push hdcBack
    call pAlphaBlend
    test eax, eax
    jnz PaintCardDone
PaintCardOpaque:
    INVOKE BitBlt, hdcBack, PNL_X, PNL_Y, PNL_W, PNL_H, hPanelDC, 0, 0, BG_ROP_COPY
PaintCardDone:
    INVOKE SelectObject, hPanelDC, hOldPanel
    INVOKE DeleteObject, hPanelBmp
    INVOKE DeleteDC, hPanelDC

    ; 3) title, accent bar, project information
    INVOKE SetBkMode, hdcBack, 1  ; TRANSPARENT text background
    INVOKE FillBoxProc, hdcBack, PNL_X+24, PNL_Y+64, PNL_W-48, 3, CLR_ACCENT
    INVOKE DrawLabelProc, hdcBack, PNL_X+24, PNL_Y+16, OFFSET strMenuTitle, CLR_TITLE, hFontTitle
    INVOKE DrawLabelProc, hdcBack, PNL_X+24, PNL_Y+80, OFFSET strMenuLine1, CLR_INFO, hFontSmall
    INVOKE DrawLabelProc, hdcBack, PNL_X+24, PNL_Y+104, OFFSET strMenuLine2, CLR_INFO, hFontSmall
    INVOKE DrawLabelProc, hdcBack, PNL_X+24, PNL_Y+128, OFFSET strMenuLine3, CLR_WHITE, hFontSmall
    INVOKE DrawLabelProc, hdcBack, PNL_X+24, PNL_Y+152, OFFSET strMenuLine4, CLR_INFO, hFontSmall

    ; 4) the four options (ESI = option index, EBX = top of its row)
    xor esi, esi
PaintOptLoop:
    mov eax, esi
    imul eax, OPT_STEP
    add eax, OPT_Y0
    mov ebx, eax
    cmp esi, hoverIdx
    jne PaintOptNormal
    INVOKE FillBoxProc, hdcBack, OPT_X0, ebx, OPT_X1-OPT_X0, OPT_H, CLR_HOVER_BG
    mov edi, CLR_HOVER_TXT
    jmp PaintOptText
PaintOptNormal:
    mov edi, CLR_WHITE
PaintOptText:
    mov edx, OFFSET optionTable
    mov eax, [edx + esi*4]
    lea ecx, [ebx + 8]
    INVOKE DrawLabelProc, hdcBack, PNL_X+40, ecx, eax, edi, hFontOpt
    inc esi
    cmp esi, 4
    jl PaintOptLoop

    ; 5) hint line
    INVOKE DrawLabelProc, hdcBack, PNL_X+24, PNL_Y+PNL_H-40, OFFSET strMenuHint, CLR_HINT, hFontSmall

    ; 6) show the finished picture in one step
    INVOKE BitBlt, hdcWin, 0, 0, WIN_W, WIN_H, hdcBack, 0, 0, BG_ROP_COPY
    INVOKE SelectObject, hdcBack, hOldBack
    INVOKE DeleteObject, hBackBmp
    INVOKE DeleteDC, hdcBack
    INVOKE EndPaint, hWnd, OFFSET psBuf
    ret
PaintMenuWindowProc ENDP

; MenuWndProc (window procedure of the picture menu - called by Windows)
; stdcall: parameters on the stack; EBX, ESI, EDI are preserved (USES).
MenuWndProc PROC USES ebx esi edi, hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
    mov eax, uMsg
    cmp eax, MW_PAINT
    je WpPaint
    cmp eax, MW_ERASEBKGND
    je WpErase
    cmp eax, MW_CHAR
    je WpChar
    cmp eax, MW_LBUTTONDOWN
    je WpClick
    cmp eax, MW_MOUSEMOVE
    je WpMove
    cmp eax, MW_CLOSE
    je WpClose
    cmp eax, MW_DESTROY
    je WpDestroy
WpDefault:
    INVOKE DefWindowProcA, hWnd, uMsg, wParam, lParam
    ret

WpErase:
    mov eax, 1
    ret

WpPaint:
    INVOKE PaintMenuWindowProc, hWnd
    xor eax, eax
    ret

WpChar:
    mov eax, wParam
    cmp eax, 27
    je WpClose
    cmp eax, '1'
    jb WpDefault
    cmp eax, '4'
    ja WpDefault
    sub eax, '0'
    mov menuChoice, eax
    INVOKE DestroyWindow, hWnd
    xor eax, eax
    ret

WpClick:
    movsx eax, WORD PTR lParam
    mov edx, lParam
    sar edx, 16
    call HitTestProc
    cmp eax, 0
    jl WpClickDone
    inc eax
    mov menuChoice, eax
    INVOKE DestroyWindow, hWnd
WpClickDone:
    xor eax, eax
    ret

WpMove:
    movsx eax, WORD PTR lParam
    mov edx, lParam
    sar edx, 16
    call HitTestProc
    cmp eax, hoverIdx
    je WpMoveDone
    mov hoverIdx, eax
    INVOKE InvalidateRect, hWnd, 0, 0
WpMoveDone:
    xor eax, eax
    ret

WpClose:
    mov menuChoice, 4
    INVOKE DestroyWindow, hWnd
    xor eax, eax
    ret

WpDestroy:
    INVOKE PostQuitMessage, 0
    xor eax, eax
    ret
MenuWndProc ENDP

; ShowPictureMenuProc
; Opens the picture window (the real robot warehouse image + the 4 menu options)
; and runs its message loop until the player chooses an option.
; Receives : nothing
; Returns : EAX = 1..4 (menu option) or 0 if the picture window is unavailable
; Preserves: everything except EAX
ShowPictureMenuProc PROC
    push ebx
    push ecx
    push edx
    push esi
    push edi

    mov menuChoice, 0
    mov hoverIdx, -1
    cmp hBgBitmap, 0
    je SpmFail

    ; GDI functions that are called through pointers
    INVOKE GetModuleHandleA, OFFSET szGdi32
    test eax, eax
    jz SpmFail
    mov ebx, eax
    INVOKE GetProcAddress, ebx, OFFSET szSetTextColor
    mov pSetTextColor, eax
    INVOKE GetProcAddress, ebx, OFFSET szAlphaBlend
    mov pAlphaBlend, eax
    INVOKE GetModuleHandleA, 0
    mov hInst, eax

    ; register the window class (once)
    cmp classRegistered, 0
    jne SpmClassReady
    mov wcBuf[0], 48  ; cbSize = sizeof(WNDCLASSEX)
    mov wcBuf[4], 0
    mov wcBuf[8], OFFSET MenuWndProc
    mov wcBuf[12], 0
    mov wcBuf[16], 0
    mov eax, hInst
    mov wcBuf[20], eax
    mov wcBuf[24], 0
    INVOKE LoadCursorA, 0, 32512
    mov wcBuf[28], eax
    mov wcBuf[32], 0
    mov wcBuf[36], 0
    mov wcBuf[40], OFFSET szClassName
    mov wcBuf[44], 0
    INVOKE RegisterClassExA, OFFSET wcBuf
    test eax, eax
    jz SpmFail
    mov classRegistered, 1
SpmClassReady:

    ; fonts
    INVOKE CreateFontA, -30, 0, 0, 0, 700, 0, 0, 0, 1, 0, 0, 5, 0, OFFSET szFontName
    mov hFontTitle, eax
    INVOKE CreateFontA, -28, 0, 0, 0, 600, 0, 0, 0, 1, 0, 0, 5, 0, OFFSET szFontName
    mov hFontOpt, eax
    INVOKE CreateFontA, -16, 0, 0, 0, 400, 0, 0, 0, 1, 0, 0, 5, 0, OFFSET szFontName
    mov hFontSmall, eax

    ; window size (client area WIN_W x WIN_H) and centred position
    mov rcWin[0], 0
    mov rcWin[4], 0
    mov rcWin[8], WIN_W
    mov rcWin[12], WIN_H
    INVOKE AdjustWindowRect, OFFSET rcWin, WIN_STYLE, 0
    mov eax, rcWin[8]
    sub eax, rcWin[0]
    mov winW, eax
    mov eax, rcWin[12]
    sub eax, rcWin[4]
    mov winH, eax
    INVOKE GetSystemMetrics, 0
    sub eax, winW
    sar eax, 1
    jns SpmXok
    xor eax, eax
SpmXok:
    mov esi, eax
    INVOKE GetSystemMetrics, 1
    sub eax, winH
    sar eax, 1
    jns SpmYok
    xor eax, eax
SpmYok:
    mov edi, eax

    INVOKE CreateWindowExA, WIN_EXSTYLE, OFFSET szClassName, OFFSET szWndTitle, WIN_STYLE, esi, edi, winW, winH, 0, 0, hInst, 0
    test eax, eax
    jz SpmFailFonts
    mov ebx, eax
    INVOKE ShowWindow, ebx, 5
    INVOKE UpdateWindow, ebx  ; sends the first WM_PAINT
    INVOKE SwitchToThisWindow, ebx, 1
    INVOKE SetForegroundWindow, ebx
    INVOKE SetFocus, ebx
    mov eax, 0
    call SetConsoleVisProc

    ; message loop: ends when WM_DESTROY posts WM_QUIT
SpmLoop:
    INVOKE GetMessageA, OFFSET msgBuf, 0, 0, 0
    cmp eax, 0
    jle SpmLoopEnd  ; 0 = WM_QUIT, -1 = error
    INVOKE TranslateMessage, OFFSET msgBuf
    INVOKE DispatchMessageA, OFFSET msgBuf
    jmp SpmLoop
SpmLoopEnd:

    ; give the keyboard focus back to the console / terminal window
    INVOKE GetConsoleWindow
    test eax, eax
    jz SpmFonts
    mov ebx, eax
    INVOKE GetAncestor, ebx, 3
    test eax, eax
    jnz SpmHaveRoot
    mov eax, ebx
SpmHaveRoot:
    mov ebx, eax
    INVOKE SwitchToThisWindow, ebx, 1
    INVOKE SetForegroundWindow, ebx
SpmFonts:
    INVOKE DeleteObject, hFontTitle
    INVOKE DeleteObject, hFontOpt
    INVOKE DeleteObject, hFontSmall
    mov eax, menuChoice
    jmp SpmExit

SpmFailFonts:
    INVOKE DeleteObject, hFontTitle
    INVOKE DeleteObject, hFontOpt
    INVOKE DeleteObject, hFontSmall
SpmFail:
    xor eax, eax
SpmExit:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
ShowPictureMenuProc ENDP

; ShowInstructionsProc
; Shows objective, collection / delivery rules, legend and controls, then waits
; for any key. It does NOT touch any game variable, so an active game is
; preserved; the caller simply redraws its own screen afterwards.
; Receives : nothing Returns : nothing Preserves: everything except EAX
ShowInstructionsProc PROC
    mov eax, 0
    call SetConsoleVisProc
    push eax
    push edx
    push esi

    mov eax, COLOR_NORMAL
    call SetTextColor
    call Clrscr

    mov eax, COLOR_LABEL
    call SetTextColor
    mov dl, 34
    mov dh, 1
    mov esi, OFFSET strInsTitle
    call PrintAtProc

    ; objective
    mov eax, COLOR_TITLE
    call SetTextColor
    mov dl, 2
    mov dh, 3
    mov esi, OFFSET strInsH1
    call PrintAtProc
    mov eax, COLOR_NORMAL
    call SetTextColor
    mov dl, 0
    mov dh, 4
    mov esi, OFFSET strInsT1
    call PrintAtProc

    ; collecting
    mov eax, COLOR_TITLE
    call SetTextColor
    mov dl, 2
    mov dh, 6
    mov esi, OFFSET strInsH2
    call PrintAtProc
    mov eax, COLOR_NORMAL
    call SetTextColor
    mov dl, 0
    mov dh, 7
    mov esi, OFFSET strInsT2a
    call PrintAtProc
    mov dl, 0
    mov dh, 8
    mov esi, OFFSET strInsT2b
    call PrintAtProc

    ; delivering
    mov eax, COLOR_TITLE
    call SetTextColor
    mov dl, 2
    mov dh, 10
    mov esi, OFFSET strInsH3
    call PrintAtProc
    mov eax, COLOR_NORMAL
    call SetTextColor
    mov dl, 0
    mov dh, 11
    mov esi, OFFSET strInsT3a
    call PrintAtProc
    mov dl, 0
    mov dh, 12
    mov esi, OFFSET strInsT3b
    call PrintAtProc
    mov dl, 0
    mov dh, 13
    mov esi, OFFSET strInsT3c
    call PrintAtProc

    ; legend: a coloured sample tile, then its meaning
    mov eax, COLOR_TITLE
    call SetTextColor
    mov dl, 2
    mov dh, 14
    mov esi, OFFSET strInsH4
    call PrintAtProc

    mov dl, 4
    mov dh, 15
    call Gotoxy
    mov eax, FACE_RIGHT
    call DrawRobotGlyphProc
    mov eax, COLOR_NORMAL
    call SetTextColor
    mov dl, 8
    mov dh, 15
    mov esi, OFFSET strInsRobot
    call PrintAtProc

    mov eax, TILE_PACKAGE
    call SetTextColor
    mov dl, 4
    mov dh, 16
    mov esi, OFFSET strPackage
    call PrintAtProc
    mov eax, COLOR_NORMAL
    call SetTextColor
    mov dl, 8
    mov dh, 16
    mov esi, OFFSET strInsPackage
    call PrintAtProc

    mov eax, TILE_SHELF
    call SetTextColor
    mov dl, 4
    mov dh, 17
    mov esi, OFFSET strShelfTile
    call PrintAtProc
    mov eax, COLOR_NORMAL
    call SetTextColor
    mov dl, 8
    mov dh, 17
    mov esi, OFFSET strInsShelf
    call PrintAtProc

    mov eax, TILE_PATH
    call SetTextColor
    mov dl, 4
    mov dh, 18
    mov esi, OFFSET strPathTile
    call PrintAtProc
    mov eax, COLOR_NORMAL
    call SetTextColor
    mov dl, 8
    mov dh, 18
    mov esi, OFFSET strInsPath
    call PrintAtProc

    mov eax, TILE_DELIVERY
    call SetTextColor
    mov dl, 4
    mov dh, 19
    mov esi, OFFSET strDeliveryTile
    call PrintAtProc
    mov eax, COLOR_NORMAL
    call SetTextColor
    mov dl, 8
    mov dh, 19
    mov esi, OFFSET strInsDelivery
    call PrintAtProc

    ; controls (Crlf moves the cursor to the start of the next line)
    mov eax, COLOR_TITLE
    call SetTextColor
    mov dl, 2
    mov dh, 21
    mov esi, OFFSET strInsH5
    call PrintAtProc
    mov eax, COLOR_NORMAL
    call SetTextColor
    mov dl, 0
    mov dh, 22
    mov esi, OFFSET strInsC1
    call PrintAtProc
    call Crlf
    mov edx, OFFSET strInsC2
    call WriteString
    call Crlf
    mov edx, OFFSET strInsC3
    call WriteString
    call Crlf

    mov eax, COLOR_OK
    call SetTextColor
    mov dl, 2
    mov dh, 26
    mov esi, OFFSET strInsBack
    call PrintAtProc

    call ReadChar
    mov eax, COLOR_NORMAL
    call SetTextColor

    pop esi
    pop edx
    pop eax
    ret
ShowInstructionsProc ENDP

; InitWarehouseProc
; Starts (or restarts) a game: copies the master template into the working
; grid and resets every game variable. It does NOT draw anything.
; Receives : nothing Returns : nothing
; Uses : ESI = source address, EDI = destination address, ECX = count
InitWarehouseProc PROC
    push eax
    push ecx
    push esi
    push edi

GenerateMapLoop:
    ; copy masterWarehouse -> warehouse, one BYTE at a time (indirect addressing)
    mov esi, OFFSET masterWarehouse
    mov edi, OFFSET warehouse
    mov ecx, LENGTHOF warehouse
CopyLoop:
    mov al, [esi]
    mov [edi], al
    inc esi
    inc edi
    loop CopyLoop  ; ECX = ECX - 1, repeat until ECX = 0

    ; reset positions
    mov robotRow, ROBOT_START_ROW
    mov robotCol, ROBOT_START_COL
    mov oldRow, ROBOT_START_ROW
    mov oldCol, ROBOT_START_COL
    mov proposedRow, ROBOT_START_ROW
    mov proposedCol, ROBOT_START_COL

    ; reset counters and flags
    mov packageCollected, 0
    mov deliveryComplete, 0
    mov deliveriesDone, 0
    mov facing, FACE_RIGHT
    mov moveCount, 0

    ; sidebar texts: Pending / Not Started
    mov packageStatusPtr, OFFSET strPkgPending
    mov packageStatusColor, COLOR_WARN
    mov deliveryStatusPtr, OFFSET strDestWaiting
    mov deliveryStatusColor, COLOR_NORMAL

    ; system status (stored only; DrawFullScreenProc will display it)
    mov curMsgPtr, OFFSET strMsgReady
    mov curMsgColor, COLOR_INFO

    ; build a random map (entrance = cell 0 is never a shelf)
    call GenerateObstaclesProc
    call FloodFillProc  ; EAX = floor tiles reachable from the entrance
    cmp eax, MIN_FREE_CELLS
    jl GenerateMapLoop  ; JL: too few free tiles -> start over (copy + new shelves)
    call PlacePackageProc  ; random reachable package tile
    call PlaceDestinationProc  ; random reachable destination tile (value 2)

    pop edi
    pop esi
    pop ecx
    pop eax
    ret
InitWarehouseProc ENDP

; DrawFullScreenProc (helper)
; Draws everything: static frame, whole grid, sidebar values and the message.
; Used at game start, after Restart and after returning from Instructions.
; Receives : nothing Returns : nothing
DrawFullScreenProc PROC
    push eax
    push edx
    call DrawStaticUIProc
    call DrawGridProc
    call UpdateSidebarProc
    mov edx, curMsgPtr
    mov eax, curMsgColor
    call UpdateStatusMsgProc
    call ParkCursorProc
    pop edx
    pop eax
    ret
DrawFullScreenProc ENDP

; DrawStaticUIProc
; Clears the screen ONCE and draws everything that never changes while playing:
; header bar, coordinate labels, grid border, sidebar labels, message box,
; legend and the bottom action bar.
; Receives : nothing Returns : nothing
DrawStaticUIProc PROC
    push eax
    push ebx
    push ecx
    push edx
    push esi

    mov eax, COLOR_NORMAL
    call SetTextColor
    call Clrscr

    ; A. header bar: white on blue, title centred
    mov eax, COLOR_HEADER
    call SetTextColor
    mov dl, 0
    mov dh, 0
    call Gotoxy
    mov al, ' '
    mov ecx, SCREEN_W
    call RepeatCharProc
    mov dl, 23
    mov dh, 0
    mov esi, OFFSET strHeader
    call PrintAtProc

    ; column labels 1..18 above the grid
    mov eax, COLOR_LABEL
    call SetTextColor
    mov loopIdx, 0  ; loopIdx = zero-based column
ColLabelLoop:
    mov eax, loopIdx
    imul eax, CELL_W  ; column * 3
    add eax, GRID_X
    mov ebx, loopIdx
    inc ebx
    cmp ebx, 9
    jg ColLabelTwoDigits
    inc eax
ColLabelTwoDigits:
    mov dl, al
    mov dh, GRID_Y - 2
    call Gotoxy
    mov eax, ebx
    call WriteDec  ; Irvine32: print EAX in decimal
    inc loopIdx
    cmp loopIdx, NUM_COLS
    jl ColLabelLoop

    ; row labels 1..11 left of the grid
    mov loopIdx, 0
RowLabelLoop:
    mov ebx, loopIdx
    inc ebx
    mov dl, 1
    cmp ebx, 9
    jle RowLabelPos
    mov dl, 0
RowLabelPos:
    mov eax, loopIdx
    add eax, GRID_Y
    mov dh, al
    call Gotoxy
    mov eax, ebx
    call WriteDec
    inc loopIdx
    cmp loopIdx, NUM_ROWS
    jl RowLabelLoop

    ; grid border (CP437 single-line box: DA C4 BF B3 C0 D9)
    mov eax, COLOR_BORDER
    call SetTextColor
    mov dl, BORDER_L
    mov dh, GRID_Y - 1
    call Gotoxy
    mov al, 0DAh
    call WriteChar
    mov al, 0C4h
    mov ecx, GRID_W
    call RepeatCharProc
    mov al, 0BFh
    call WriteChar

    mov loopIdx, 0
SideBorderLoop:
    mov eax, loopIdx
    add eax, GRID_Y
    mov dh, al
    mov dl, BORDER_L
    call Gotoxy
    mov al, 0B3h
    call WriteChar
    mov eax, loopIdx
    add eax, GRID_Y
    mov dh, al
    mov dl, BORDER_R
    call Gotoxy
    mov al, 0B3h
    call WriteChar
    inc loopIdx
    cmp loopIdx, NUM_ROWS
    jl SideBorderLoop

    mov dl, BORDER_L
    mov dh, GRID_Y + NUM_ROWS
    call Gotoxy
    mov al, 0C0h
    call WriteChar
    mov al, 0C4h
    mov ecx, GRID_W
    call RepeatCharProc
    mov al, 0D9h
    call WriteChar

    ; sidebar title, separator line and labels
    mov eax, COLOR_LABEL
    call SetTextColor
    mov dl, SB_X
    mov dh, SB_TITLE_Y
    mov esi, OFFSET strSbTitle
    call PrintAtProc

    mov eax, COLOR_BORDER
    call SetTextColor
    mov dl, SB_X
    mov dh, SB_SEP_Y
    call Gotoxy
    mov al, 0C4h
    mov ecx, MSG_W
    call RepeatCharProc

    mov eax, COLOR_NORMAL
    call SetTextColor
    mov dl, SB_X
    mov dh, SB_NAME_Y
    mov esi, OFFSET strSbName
    call PrintAtProc
    mov dl, SB_X
    mov dh, SB_POS_Y
    mov esi, OFFSET strSbPos
    call PrintAtProc
    mov dl, SB_X
    mov dh, SB_MOVE_Y
    mov esi, OFFSET strSbMove
    call PrintAtProc
    mov dl, SB_X
    mov dh, SB_DELIV_Y
    mov esi, OFFSET strSbDeliv
    call PrintAtProc
    mov dl, SB_X
    mov dh, SB_PKG_Y
    mov esi, OFFSET strSbPackage
    call PrintAtProc
    mov dl, SB_X
    mov dh, SB_DEL_Y
    mov esi, OFFSET strSbDelivery
    call PrintAtProc
    mov dl, SB_X
    mov dh, SB_DIR_Y
    mov esi, OFFSET strSbDir
    call PrintAtProc
    mov dl, SB_X
    mov dh, SB_SYS_Y
    mov esi, OFFSET strSbSystem
    call PrintAtProc

    ; bordered system-message box (3 rows high)
    mov eax, COLOR_BORDER
    call SetTextColor
    mov dl, SB_X - 1
    mov dh, MSGBOX_TOP_Y
    call Gotoxy
    mov al, 0DAh
    call WriteChar
    mov al, 0C4h
    mov ecx, MSG_W
    call RepeatCharProc
    mov al, 0BFh
    call WriteChar

    mov dl, SB_X - 1
    mov dh, MSG_Y
    call Gotoxy
    mov al, 0B3h
    call WriteChar
    mov dl, SB_X + MSG_W
    mov dh, MSG_Y
    call Gotoxy
    mov al, 0B3h
    call WriteChar

    mov dl, SB_X - 1
    mov dh, MSGBOX_BOT_Y
    call Gotoxy
    mov al, 0C0h
    call WriteChar
    mov al, 0C4h
    mov ecx, MSG_W
    call RepeatCharProc
    mov al, 0D9h
    call WriteChar

    ; legend under the grid (sample tile in its colour, then its name)
    mov dl, GRID_X
    mov dh, LEGEND_Y
    call Gotoxy
    mov eax, FACE_RIGHT
    call DrawRobotGlyphProc
    mov eax, COLOR_NORMAL
    call SetTextColor
    mov edx, OFFSET strLegRobot
    call WriteString

    mov eax, TILE_PACKAGE
    call SetTextColor
    mov edx, OFFSET strPackage
    call WriteString
    mov eax, COLOR_NORMAL
    call SetTextColor
    mov edx, OFFSET strLegPackage
    call WriteString

    mov eax, TILE_SHELF
    call SetTextColor
    mov edx, OFFSET strShelfTile
    call WriteString
    mov eax, COLOR_NORMAL
    call SetTextColor
    mov edx, OFFSET strLegShelf
    call WriteString

    mov eax, TILE_DELIVERY
    call SetTextColor
    mov edx, OFFSET strDeliveryTile
    call WriteString
    mov eax, COLOR_NORMAL
    call SetTextColor
    mov edx, OFFSET strLegDelivery
    call WriteString

    ; D. bottom action bar (black on light gray)
    mov eax, COLOR_BAR
    call SetTextColor
    mov dl, 0
    mov dh, BAR_Y
    call Gotoxy
    mov al, ' '
    mov ecx, SCREEN_W
    call RepeatCharProc
    mov dl, 10
    mov dh, BAR_Y
    mov esi, OFFSET strActionBar
    call PrintAtProc

    mov eax, COLOR_NORMAL
    call SetTextColor

    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
DrawStaticUIProc ENDP

; DrawGridProc
; Draws all 11 x 18 cells by calling DrawCellProc for every (row, column).
; Receives : nothing Returns : nothing
DrawGridProc PROC
    push eax
    push ebx

    mov gridRow, 0
GridRowLoop:
    mov gridCol, 0
GridColLoop:
    mov eax, gridRow
    mov ebx, gridCol
    call DrawCellProc
    inc gridCol
    cmp gridCol, NUM_COLS
    jl GridColLoop
    inc gridRow
    cmp gridRow, NUM_ROWS
    jl GridRowLoop

    pop ebx
    pop eax
    ret
DrawGridProc ENDP

; DrawCellProc
; Draws ONE warehouse cell at its screen position. The robot and the package
; are OVERLAYS: they are chosen here at draw time, the array is never changed.
; screen X = GRID_X + column * CELL_W screen Y = GRID_Y + row
; Receives : EAX = row (0..10), EBX = column (0..17)
; Returns : nothing
; Preserves: all registers
DrawCellProc PROC
    push eax
    push ebx
    push ecx
    push edx
    push esi

    mov cellRow, eax
    mov cellCol, ebx

    ; screen position -> Gotoxy
    mov eax, cellCol
    imul eax, CELL_W
    add eax, GRID_X
    mov dl, al
    mov eax, cellRow
    add eax, GRID_Y
    mov dh, al
    call Gotoxy

    ; 1) is the ROBOT on this cell? (needs BOTH row and column equal)
    mov eax, cellRow
    cmp eax, robotRow
    jne CellCheckPackage
    mov eax, cellCol
    cmp eax, robotCol
    jne CellCheckPackage
    mov eax, facing
    call DrawRobotGlyphProc
    jmp CellDrawn

    ; 2) is the PACKAGE here AND still waiting to be collected?
CellCheckPackage:
    cmp packageCollected, 0
    jnz CellTerrain
    mov eax, cellRow
    cmp eax, packageRow
    jne CellTerrain
    mov eax, cellCol
    cmp eax, packageCol
    jne CellTerrain
    mov eax, TILE_PACKAGE
    call SetTextColor
    mov edx, OFFSET strPackage
    call WriteString
    jmp CellDrawn

    ; 3) otherwise draw what the array says (path, shelf, delivery)
CellTerrain:
    mov eax, cellRow
    mov ebx, cellCol
    call GetCellValueProc
    cmp eax, CELL_DELIVERY
    je CellDelivery
    cmp eax, CELL_SHELF
    je CellShelf
    mov eax, TILE_PATH
    call SetTextColor
    mov edx, OFFSET strPathTile
    call WriteString
    jmp CellDrawn
CellShelf:
    mov eax, TILE_SHELF
    call SetTextColor
    mov edx, OFFSET strShelfTile
    call WriteString
    jmp CellDrawn
CellDelivery:
    mov eax, TILE_DELIVERY
    call SetTextColor
    mov edx, OFFSET strDeliveryTile
    call WriteString

CellDrawn:
    mov eax, COLOR_NORMAL
    call SetTextColor

    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
DrawCellProc ENDP

; UpdateSidebarProc
; Redraws ONLY the changing sidebar values: move count, package status,
; delivery status and (after delivery) the total-moves line.
; Receives : nothing Returns : nothing
UpdateSidebarProc PROC
    push eax
    push edx
    push esi

    ; robot name
    mov eax, COLOR_TITLE
    call SetTextColor
    mov dl, SB_VAL_X
    mov dh, SB_NAME_Y
    mov esi, OFFSET robotName
    call PrintAtProc

    ; current position (displayed one-based: internal + 1)
    mov eax, COLOR_INFO
    call SetTextColor
    mov dl, SB_VAL_X
    mov dh, SB_POS_Y
    call Gotoxy
    mov edx, OFFSET strPosRow
    call WriteString
    mov eax, robotRow
    inc eax
    call WriteDec
    mov edx, OFFSET strPosCol
    call WriteString
    mov eax, robotCol
    inc eax
    call WriteDec
    mov edx, OFFSET strSpaces3
    call WriteString

    ; move count, always 3 digits
    mov dl, SB_VAL_X
    mov dh, SB_MOVE_Y
    call Gotoxy
    mov eax, moveCount
    call WriteThreeDigitsProc

    ; deliveries (n/3)
    mov dl, SB_VAL_X
    mov dh, SB_DELIV_Y
    call Gotoxy
    mov eax, deliveriesDone
    call WriteDec
    mov edx, OFFSET strSlashTotal
    call WriteString

    call UpdateDirectionProc

    ; package status
    mov eax, packageStatusColor
    call SetTextColor
    mov dl, SB_VAL_X
    mov dh, SB_PKG_Y
    mov esi, packageStatusPtr
    call PrintAtProc

    ; delivery status
    mov eax, deliveryStatusColor
    call SetTextColor
    mov dl, SB_VAL_X
    mov dh, SB_DEL_Y
    mov esi, deliveryStatusPtr
    call PrintAtProc

    ; result line: only visible after a successful delivery
    cmp deliveryComplete, 0
    jz SidebarClearResult
    mov eax, COLOR_OK
    call SetTextColor
    mov dl, SB_X
    mov dh, SB_RESULT_Y
    mov esi, OFFSET strResultPrefix
    call PrintAtProc
    mov eax, moveCount
    call WriteThreeDigitsProc
    mov edx, OFFSET strResultSuffix
    call WriteString
    jmp SidebarDone
SidebarClearResult:
    mov eax, COLOR_NORMAL
    call SetTextColor
    mov dl, SB_X
    mov dh, SB_RESULT_Y
    mov esi, OFFSET strBlankMsg
    call PrintAtProc
SidebarDone:
    mov eax, COLOR_NORMAL
    call SetTextColor

    pop esi
    pop edx
    pop eax
    ret
UpdateSidebarProc ENDP

; UpdateStatusMsgProc
; Shows a message inside the SYSTEM STATUS box (old text is erased first) and
; remembers it so a full redraw can show it again.
; Receives : EDX = OFFSET of message string, EAX = colour attribute
; Returns : nothing
; Preserves: all registers
UpdateStatusMsgProc PROC
    push eax
    push edx

    mov curMsgPtr, edx
    mov curMsgColor, eax
    call SetTextColor

    push edx
    mov dl, SB_X
    mov dh, MSG_Y
    call Gotoxy
    mov edx, OFFSET strBlankMsg
    call WriteString
    mov dl, SB_X
    mov dh, MSG_Y
    call Gotoxy
    pop edx
    call WriteString

    mov eax, COLOR_NORMAL
    call SetTextColor

    pop edx
    pop eax
    ret
UpdateStatusMsgProc ENDP

; GROUP B - LOGIC AND MOVEMENT PROCEDURES

; GetCellValueProc (helper used by drawing and delivery check)
; Row-major address calculation:
; offset = row * NUM_COLS + column
; address = OFFSET warehouse + offset
; Example: row 6, column 15 -> 6 * 18 + 15 = 123 -> warehouse[123]
; Receives : EAX = row, EBX = column
; Returns : EAX = cell value (0 path, 1 shelf, 2 delivery)
; Preserves: everything except EAX
GetCellValueProc PROC
    push esi
    imul eax, NUM_COLS  ; EAX = row * 18
    add eax, ebx  ; EAX = row * 18 + column  (the offset)
    mov esi, OFFSET warehouse
    add esi, eax
    movzx eax, BYTE PTR [esi]  ; indirect read of ONE byte, zero-extended
    pop esi
    ret
GetCellValueProc ENDP

; GameLoopProc
; Draws the screen, then repeats: read key -> act. Returns to the caller
; (the main menu) when the player presses M. Q / ESC end the program.
; Receives : nothing Returns : nothing
GameLoopProc PROC
    mov eax, 0
    call SetConsoleVisProc
    push eax
    push edx

    call DrawFullScreenProc

GameLoopTop:
    call ParkCursorProc
    call ReadInputProc
    cmp eax, ACT_NONE
    je GameLoopTop
    cmp eax, ACT_EXIT
    je GameLoopExit
    cmp eax, ACT_MENU
    je GameLoopMenu
    cmp eax, ACT_RESTART
    je GameLoopRestart
    cmp eax, ACT_INSTR
    je GameLoopInstr

    ; otherwise EAX is a direction (1..4)
    cmp deliveryComplete, 0
    jnz GameLoopFinished  ; JNZ: game already won -> no movement

    call SetFacingProc
    call CalculateNextPosProc
    call CheckBoundaryProc
    test eax, eax  ; TEST sets ZF when EAX = 0
    jz GameLoopTop
    call CheckObstacleProc
    test eax, eax
    jz GameLoopTop
    call UpdateGameStateProc
    cmp deliveryComplete, 0
    jz GameLoopTop  ; JZ: 3rd delivery not done yet -> keep playing

    ; all deliveries done: save the record and show the results screen
    mov eax, 1200
    call Delay  ; Irvine32: wait 1200 ms so the last move stays visible
    call GameFinishedProc
    cmp eax, ACT_EXIT
    je GameLoopExit
    cmp eax, ACT_MENU
    je GameLoopMenu
    call RestartProc
    jmp GameLoopTop

GameLoopFinished:
    mov edx, OFFSET strMsgDelivered
    mov eax, COLOR_OK
    call UpdateStatusMsgProc
    jmp GameLoopTop

GameLoopRestart:
    call RestartProc
    jmp GameLoopTop

GameLoopInstr:
    call ShowInstructionsProc
    call DrawFullScreenProc
    jmp GameLoopTop

GameLoopExit:
    call ExitProc

GameLoopMenu:
    pop edx
    pop eax
    ret
GameLoopProc ENDP

; ReadInputProc
; Waits for a key and converts it into an ACTION CODE. It polls the no-wait
; Irvine32 procedure ReadKey (ZF = 1 means "no key") and sleeps POLL_DELAY_MS
; milliseconds between polls, so the CPU is not kept busy and nothing is redrawn.
;
; How ReadKey reports keys (Irvine32): AL = ASCII code, AH = scan code.
; For an extended key such as an arrow, AL is 0 (or 0E0h) and the identity of
; the key is in AH (scan code). The extended prefix is NOT a separate
; character: it arrives together with the scan code in the same call.
; As a backup we also compare DX with the Windows virtual-key codes. Some
; Irvine32 versions fill DX with them; if yours does not, this backup simply
; never matches and the scan-code check in AH does the work.
;
; Scan codes: Up 48h, Down 50h, Left 4Bh, Right 4Dh.
; Receives : nothing
; Returns : EAX = ACT_UP / DOWN / LEFT / RIGHT / RESTART / INSTR / MENU /
; EXIT, or ACT_NONE for any other key
; Preserves: everything except EAX
ReadInputProc PROC
    push edx
    push ebx  ; ReadKey changes EBX (control-key flags)

InputWait:
    call ReadKey  ; AL = ASCII, AH = scan code, DX = virtual key
    jnz InputGotKey  ; JNZ: ZF=0 -> a key was waiting
    mov eax, POLL_DELAY_MS
    call Delay  ; Irvine32: pause so the CPU is not busy-waiting
    jmp InputWait

InputGotKey:
    cmp al, 0
    je InputExtended  ; AL = 0     -> extended key
    cmp al, 0E0h
    je InputExtended  ; AL = 0E0h  -> extended key (another prefix)

    ; ordinary keys (both upper and lower case accepted)
    cmp al, KEY_ESC
    je InputExit
    cmp al, 'Q'
    je InputExit
    cmp al, 'q'
    je InputExit
    cmp al, 'R'
    je InputRestart
    cmp al, 'r'
    je InputRestart
    cmp al, 'I'
    je InputInstr
    cmp al, 'i'
    je InputInstr
    cmp al, 'M'
    je InputMenu
    cmp al, 'm'
    je InputMenu
    jmp InputUnknown

InputExtended:
    cmp ah, KEY_SC_UP  ; main check: scan code in AH
    je InputUp
    cmp ah, KEY_SC_DOWN
    je InputDown
    cmp ah, KEY_SC_LEFT
    je InputLeft
    cmp ah, KEY_SC_RIGHT
    je InputRight
    cmp dx, KEY_VK_UP  ; backup check: virtual-key code in DX
    je InputUp
    cmp dx, KEY_VK_DOWN
    je InputDown
    cmp dx, KEY_VK_LEFT
    je InputLeft
    cmp dx, KEY_VK_RIGHT
    je InputRight
    jmp InputUnknown

InputUp:
    mov eax, ACT_UP
    jmp InputDone
InputDown:
    mov eax, ACT_DOWN
    jmp InputDone
InputLeft:
    mov eax, ACT_LEFT
    jmp InputDone
InputRight:
    mov eax, ACT_RIGHT
    jmp InputDone
InputRestart:
    mov eax, ACT_RESTART
    jmp InputDone
InputInstr:
    mov eax, ACT_INSTR
    jmp InputDone
InputMenu:
    mov eax, ACT_MENU
    jmp InputDone
InputExit:
    mov eax, ACT_EXIT
    jmp InputDone
InputUnknown:
    mov eax, ACT_NONE
InputDone:
    pop ebx
    pop edx
    ret
ReadInputProc ENDP

; CalculateNextPosProc
; Computes the PROPOSED position. The robot's real position is NOT changed.
; Up : proposedRow = robotRow - 1 Down : proposedRow = robotRow + 1
; Left : proposedCol = robotCol - 1 Right : proposedCol = robotCol + 1
; Receives : EAX = direction code (ACT_UP / DOWN / LEFT / RIGHT)
; Returns : proposedRow and proposedCol (global variables)
; Preserves: all registers
CalculateNextPosProc PROC
    push ebx

    mov ebx, robotRow
    mov proposedRow, ebx
    mov ebx, robotCol
    mov proposedCol, ebx

    cmp eax, ACT_UP
    je CalcUp
    cmp eax, ACT_DOWN
    je CalcDown
    cmp eax, ACT_LEFT
    je CalcLeft
    cmp eax, ACT_RIGHT
    je CalcRight
    jmp CalcDone
CalcUp:
    dec proposedRow
    jmp CalcDone
CalcDown:
    inc proposedRow
    jmp CalcDone
CalcLeft:
    dec proposedCol
    jmp CalcDone
CalcRight:
    inc proposedCol
CalcDone:
    pop ebx
    ret
CalculateNextPosProc ENDP

; CheckBoundaryProc
; Valid only if 0 <= proposedRow < NUM_ROWS and 0 <= proposedCol < NUM_COLS.
; proposedRow/Col are SIGNED, so a move above row 0 gives -1 and JL catches it.
; Receives : proposedRow, proposedCol (global)
; Returns : EAX = 1 inside the warehouse, EAX = 0 outside (message is shown)
; Preserves: everything except EAX
CheckBoundaryProc PROC
    push edx

    cmp proposedRow, 0
    jl BoundaryOutside  ; JL  (signed less): row is -1 or smaller
    cmp proposedRow, NUM_ROWS
    jge BoundaryOutside  ; JGE (signed >=)  : row is 11 or larger
    cmp proposedCol, 0
    jl BoundaryOutside
    cmp proposedCol, NUM_COLS
    jge BoundaryOutside

    mov eax, 1
    jmp BoundaryDone

BoundaryOutside:
    mov edx, OFFSET strMsgBoundary
    mov eax, COLOR_ERROR
    call UpdateStatusMsgProc
    mov eax, 0
BoundaryDone:
    pop edx
    ret
CheckBoundaryProc ENDP

; CheckObstacleProc
; Looks at the proposed cell using INDIRECT addressing:
; offset = proposedRow * NUM_COLS + proposedCol
; ESI = OFFSET warehouse + offset (pointer to the cell)
; BL = [ESI] (the cell's value)
; Receives : proposedRow, proposedCol (already known to be inside the grid)
; Returns : EAX = 1 if the cell can be entered (value 0 or 2)
; EAX = 0 if it is a shelf (value 1); message is shown
; Preserves: everything except EAX
CheckObstacleProc PROC
    push ebx
    push edx
    push esi

    mov eax, proposedRow
    imul eax, NUM_COLS  ; EAX = row * 18
    add eax, proposedCol
    mov esi, OFFSET warehouse
    add esi, eax
    mov bl, [esi]  ; indirect addressing: read the cell value
    cmp bl, CELL_SHELF
    je ObstacleBlocked

    mov eax, 1
    jmp ObstacleDone

ObstacleBlocked:
    mov edx, OFFSET strMsgBlocked
    mov eax, COLOR_ERROR
    call UpdateStatusMsgProc
    mov eax, 0
ObstacleDone:
    pop esi
    pop edx
    pop ebx
    ret
CheckObstacleProc ENDP

; UpdateGameStateProc
; Performs a VALID move: saves the old position, moves the robot, counts the
; move, redraws ONLY the old and new cell (flicker-free), checks package /
; delivery events and refreshes the sidebar.
; Receives : proposedRow, proposedCol (global; already validated)
; Returns : nothing
; Preserves: all registers
UpdateGameStateProc PROC
    push eax
    push ebx
    push ecx
    push edx

    ; remember where the robot was
    mov eax, robotRow
    mov oldRow, eax
    mov eax, robotCol
    mov oldCol, eax

    ; move the robot
    mov eax, proposedRow
    mov robotRow, eax
    mov eax, proposedCol
    mov robotCol, eax

    ; count the move (capped at 999 so the display keeps 3 digits)
    cmp moveCount, MAX_MOVES
    jge SkipCountIncrement
    inc moveCount
SkipCountIncrement:

    ; redraw ONLY the old and the new tile (flicker-free)
    mov eax, oldRow
    mov ebx, oldCol
    call DrawCellProc
    mov eax, robotRow
    mov ebx, robotCol
    call DrawCellProc

    ; default message after a normal move
    cmp packageCollected, 0
    jnz MoveMsgCollected
    mov edx, OFFSET strMsgReady
    mov eax, COLOR_INFO
    jmp MoveMsgShow
MoveMsgCollected:
    mov edx, OFFSET strMsgCollected
    mov eax, COLOR_OK
MoveMsgShow:
    call UpdateStatusMsgProc

    ; special events may replace that message
    call CheckPackageAndDeliveryProc
    call UpdateSidebarProc

    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
UpdateGameStateProc ENDP

; CheckPackageAndDeliveryProc
; PACKAGE: not collected yet AND robot row = package row AND robot column
; package column -> collected.
; DELIVERY: the cell UNDER the robot has value 2.
; package collected -> delivery complete,
; otherwise -> warning, delivery stays incomplete.
; Receives : robotRow, robotCol, packageRow, packageCol, flags (global)
; Returns : updates packageCollected, deliveryComplete, status pointers and
; the system message
; Preserves: all registers
CheckPackageAndDeliveryProc PROC
    push eax
    push ebx
    push edx

    ; package pick-up
    cmp packageCollected, 0
    jnz CheckDelivery
    mov eax, robotRow
    cmp eax, packageRow
    jne CheckDelivery
    mov eax, robotCol
    cmp eax, packageCol
    jne CheckDelivery

    mov packageCollected, 1
    mov packageStatusPtr, OFFSET strPkgCollected
    mov packageStatusColor, COLOR_OK
    mov deliveryStatusPtr, OFFSET strDestActive
    mov deliveryStatusColor, COLOR_WARN
    mov edx, OFFSET strMsgCollected
    mov eax, COLOR_OK
    call UpdateStatusMsgProc

CheckDelivery:
    mov eax, robotRow
    mov ebx, robotCol
    call GetCellValueProc  ; EAX = value of the cell under the robot
    cmp eax, CELL_DELIVERY
    jne PackageDeliveryDone

    cmp packageCollected, 0
    je DeliveryNoPackage

    ; a delivery is complete (robot on green WITH the package)
    inc deliveriesDone
    cmp deliveriesDone, TOTAL_DELIVERIES
    jge DeliveryAllDone  ; JGE: that was the 3rd delivery -> game finished

    ; deliveries 1 and 2: show "Delivery N of 3", then create the next package
    mov al, '0'
    add al, BYTE PTR deliveriesDone  ; low byte of the counter -> ASCII digit
    mov strMsgDeliveredN[9], al  ; patch the digit into the message text
    call GenerateNextPackageProc
    mov eax, packageRow
    mov ebx, packageCol
    call DrawCellProc
    mov eax, destRow
    mov ebx, destCol
    call DrawCellProc
    mov packageStatusPtr, OFFSET strPkgPending
    mov packageStatusColor, COLOR_WARN
    mov deliveryStatusPtr, OFFSET strDestWaiting
    mov deliveryStatusColor, COLOR_NORMAL
    mov edx, OFFSET strMsgDeliveredN
    mov eax, COLOR_OK
    call UpdateStatusMsgProc
    jmp PackageDeliveryDone

DeliveryAllDone:
    mov deliveryComplete, 1
    mov packageStatusPtr, OFFSET strPkgDelivered
    mov packageStatusColor, COLOR_OK
    mov deliveryStatusPtr, OFFSET strDestReached
    mov deliveryStatusColor, COLOR_OK
    mov edx, OFFSET strMsgDelivered
    mov eax, COLOR_OK
    call UpdateStatusMsgProc
    jmp PackageDeliveryDone

DeliveryNoPackage:
    mov edx, OFFSET strMsgNeedPackage
    mov eax, COLOR_WARN
    call UpdateStatusMsgProc

PackageDeliveryDone:
    pop edx
    pop ebx
    pop eax
    ret
CheckPackageAndDeliveryProc ENDP

; RestartProc
; Reinitialises the whole game and redraws the complete interface.
; Receives : nothing Returns : nothing
RestartProc PROC
    call InitWarehouseProc
    call DrawFullScreenProc
    ret
RestartProc ENDP

; ExitProc
; Restores light gray on black, clears the screen and ends the program.
; Receives : nothing Returns : never returns
ExitProc PROC
    mov eax, COLOR_NORMAL
    call SetTextColor
    call Clrscr
    mov dl, 0
    mov dh, 0
    call Gotoxy
    INVOKE ExitProcess, 0  ; Windows API (stdcall) ends the process
ExitProc ENDP

; SetConsoleVisProc
; Shows or hides the console window (the picture windows are used instead).
; Receives : EAX = ShowWindow command (0 = hide, 5 = show)
; Returns : nothing Preserves: all registers
SetConsoleVisProc PROC
    push ebx
    push eax
    INVOKE GetConsoleWindow
    test eax, eax
    jz DoneVis
    mov ebx, eax
    pop eax
    INVOKE ShowWindow, ebx, eax
    pop ebx
    ret
DoneVis:
    pop eax
    pop ebx
    ret
SetConsoleVisProc ENDP

; RANDOM MAP, NAME ENTRY AND RECORD PROCEDURES

; RandomBelowProc (helper)
; Receives : EAX = n (n >= 1)
; Returns : EAX = random number 0 .. n-1 (Irvine32 RandomRange)
; Preserves: everything except EAX
RandomBelowProc PROC
    push ebx
    push ecx
    push edx
    push esi
    push edi
    call RandomRange  ; Irvine32: EAX = n in, random 0..n-1 out
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
RandomBelowProc ENDP

; GenerateObstaclesProc
; Turns about OBSTACLE_PERCENT % of the tiles into shelves. Tile 0 (the
; entrance, top-left) is skipped, so it can never be a shelf.
; Receives : nothing Returns : nothing (warehouse[] is changed)
; Preserves: all registers
GenerateObstaclesProc PROC
    push eax
    push ebx
    push esi

    mov esi, OFFSET warehouse
    mov ebx, 1
ObsLoop:
    mov eax, 100
    call RandomBelowProc
    cmp eax, OBSTACLE_PERCENT
    jge ObsNext
    mov BYTE PTR [esi + ebx], CELL_SHELF  ; indirect store: warehouse[offset] = 1
ObsNext:
    inc ebx
    cmp ebx, GRID_SIZE
    jl ObsLoop

    pop esi
    pop ebx
    pop eax
    ret
GenerateObstaclesProc ENDP

; TryNeighborProc (helper of FloodFillProc)
; If tile (row, col) is inside the grid, is floor (0) and not yet visited, it is
; marked visited and added to the queue.
; Receives : EAX = row (signed), EBX = column (signed)
; Returns : nothing Preserves: all registers
TryNeighborProc PROC
    push eax
    push ebx
    push ecx
    push esi

    cmp eax, 0
    jl TryDone
    cmp eax, NUM_ROWS
    jge TryDone
    cmp ebx, 0
    jl TryDone
    cmp ebx, NUM_COLS
    jge TryDone

    imul eax, NUM_COLS  ; offset = row * NUM_COLS + col
    add eax, ebx
    mov esi, OFFSET warehouse
    cmp BYTE PTR [esi + eax], CELL_PATH
    jne TryDone
    mov esi, OFFSET visited
    cmp BYTE PTR [esi + eax], 0
    jne TryDone
    mov BYTE PTR [esi + eax], 1
    mov esi, OFFSET queueArr
    mov ecx, queueTail
    mov [esi + ecx*4], eax  ; queue[tail] = offset   (DWORD entries)
    inc queueTail
TryDone:
    pop esi
    pop ecx
    pop ebx
    pop eax
    ret
TryNeighborProc ENDP

; FloodFillProc
; Starting at the entrance (offset 0) it visits every floor tile that can be
; reached by walking up/down/left/right (breadth-first search with a queue).
; Floor tiles that were NOT reached are closed pockets: they become shelves.
; Afterwards every floor tile is reachable from the entrance.
; Receives : nothing
; Returns : EAX = number of reachable floor tiles
; Preserves: everything except EAX
FloodFillProc PROC
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; clear visited[]
    mov edi, OFFSET visited
    mov ecx, GRID_SIZE
    mov al, 0
ClearVisitedLoop:
    mov [edi], al
    inc edi
    loop ClearVisitedLoop

    ; queue = { entrance }
    mov esi, OFFSET queueArr
    mov DWORD PTR [esi], 0  ; queue[0] = offset 0
    mov queueHead, 0
    mov queueTail, 1
    mov visited, 1

FillLoop:
    mov eax, queueHead
    cmp eax, queueTail
    jge FillDone  ; JGE: head >= tail -> queue empty -> finished
    mov esi, OFFSET queueArr
    mov ebx, [esi + eax*4]
    inc queueHead
    mov eax, ebx
    xor edx, edx
    mov ecx, NUM_COLS
    div ecx  ; EAX = offset / 18 = row,  EDX = offset MOD 18 = column
    mov fillRow, eax
    mov fillCol, edx
    mov eax, fillRow
    dec eax
    mov ebx, fillCol
    call TryNeighborProc
    mov eax, fillRow
    inc eax
    mov ebx, fillCol
    call TryNeighborProc
    mov eax, fillRow
    mov ebx, fillCol
    dec ebx
    call TryNeighborProc
    mov eax, fillRow
    mov ebx, fillCol
    inc ebx
    call TryNeighborProc
    jmp FillLoop

FillDone:
    ; close unreachable pockets and count reachable floor tiles
    mov esi, OFFSET warehouse
    mov edi, OFFSET visited
    mov ecx, GRID_SIZE
    xor edx, edx  ; EDX = count of reachable floor tiles
SealLoop:
    cmp BYTE PTR [esi], CELL_PATH
    jne SealNext
    cmp BYTE PTR [edi], 0
    jne SealCount  ; JNE: floor and reachable -> count it
    mov BYTE PTR [esi], CELL_SHELF  ; floor but unreachable -> make it a shelf
    jmp SealNext
SealCount:
    inc edx
SealNext:
    inc esi
    inc edi
    loop SealLoop
    mov eax, edx

    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
FloodFillProc ENDP

; PlacePackageProc
; Picks a random floor tile for the package. Never the entrance, never a shelf,
; never the destination (value 2) and never under the robot.
; Receives : robotRow, robotCol Returns : packageRow, packageCol
; Preserves: all registers
PlacePackageProc PROC
    push eax
    push ebx
    push ecx
    push edx
    push esi

PlacePkgTry:
    mov eax, GRID_SIZE
    call RandomBelowProc
    mov ebx, eax
    cmp ebx, 0
    je PlacePkgTry
    mov esi, OFFSET warehouse
    cmp BYTE PTR [esi + ebx], CELL_PATH
    jne PlacePkgTry  ; JNE: shelf or destination -> try again
    mov eax, robotRow
    imul eax, NUM_COLS
    add eax, robotCol
    cmp ebx, eax
    je PlacePkgTry  ; JE: robot stands there -> try again
    mov eax, ebx
    xor edx, edx
    mov ecx, NUM_COLS
    div ecx
    mov packageRow, eax
    mov packageCol, edx

    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
PlacePackageProc ENDP

; PlaceDestinationProc
; Picks a random floor tile for the destination and stores value 2 there.
; Never the entrance, a shelf, the package tile or the robot's tile.
; Receives : robotRow/Col, packageRow/Col Returns : destRow, destCol
; Preserves: all registers
PlaceDestinationProc PROC
    push eax
    push ebx
    push ecx
    push edx
    push esi

PlaceDestTry:
    mov eax, GRID_SIZE
    call RandomBelowProc
    mov ebx, eax
    cmp ebx, 0
    je PlaceDestTry
    mov esi, OFFSET warehouse
    cmp BYTE PTR [esi + ebx], CELL_PATH
    jne PlaceDestTry
    mov eax, robotRow
    imul eax, NUM_COLS
    add eax, robotCol
    cmp ebx, eax
    je PlaceDestTry  ; not under the robot
    mov eax, packageRow
    imul eax, NUM_COLS
    add eax, packageCol
    cmp ebx, eax
    je PlaceDestTry
    mov BYTE PTR [esi + ebx], CELL_DELIVERY
    mov eax, ebx
    xor edx, edx
    mov ecx, NUM_COLS
    div ecx
    mov destRow, eax
    mov destCol, edx

    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
PlaceDestinationProc ENDP

; GenerateNextPackageProc
; After a delivery: the old destination becomes normal floor again, then a new
; package and a new destination are placed on reachable floor tiles.
; Receives : nothing Returns : new packageRow/Col, destRow/Col
; Preserves: all registers
GenerateNextPackageProc PROC
    push eax
    push esi

    mov eax, destRow  ; offset = destRow * NUM_COLS + destCol
    imul eax, NUM_COLS
    add eax, destCol
    mov esi, OFFSET warehouse
    mov BYTE PTR [esi + eax], CELL_PATH
    mov packageCollected, 0
    call PlacePackageProc
    call PlaceDestinationProc

    pop esi
    pop eax
    ret
GenerateNextPackageProc ENDP

; NameEntryProc
; Asks for a robot name (max ROBOT_NAME_MAX characters). Printable keys are
; added, Backspace erases, Enter confirms. Empty name -> "ROBO-1".
; Receives : nothing Returns : robotName (zero-terminated), robotNameLen
; Preserves: everything except EAX
NameEntryProc PROC
    mov eax, 0
    call SetConsoleVisProc
    push eax
    push ebx
    push edx
    push esi
    push edi

    mov showCaret, 1  ; the mirror window draws a caret while typing
    mov eax, COLOR_NORMAL
    call SetTextColor
    call Clrscr

    mov eax, COLOR_TITLE
    call SetTextColor
    mov dl, 36
    mov dh, 8
    mov esi, OFFSET strNameTitle
    call PrintAtProc
    mov eax, COLOR_NORMAL
    call SetTextColor
    mov dl, 24
    mov dh, 10
    mov esi, OFFSET strNamePrompt
    call PrintAtProc
    mov dl, 24
    mov dh, 15
    mov esi, OFFSET strNameHint
    call PrintAtProc
    mov eax, COLOR_LABEL
    call SetTextColor
    mov dl, NAME_X - 2
    mov dh, NAME_Y
    mov esi, OFFSET strNameArrow
    call PrintAtProc

    mov eax, COLOR_INFO
    call SetTextColor
    mov dl, NAME_X
    mov dh, NAME_Y
    call Gotoxy
    mov robotNameLen, 0

NameKeyLoop:
    call ReadChar
    cmp al, 0Dh
    je NameDone
    cmp al, 08h
    je NameBackspace
    cmp al, 32
    jb NameKeyLoop  ; JB (unsigned): control keys / extended keys -> ignore
    cmp al, 126
    ja NameKeyLoop  ; JA (unsigned): not a printable ASCII character
    cmp robotNameLen, ROBOT_NAME_MAX
    jae NameKeyLoop
    mov esi, OFFSET robotName
    mov ebx, robotNameLen
    mov [esi + ebx], al
    inc robotNameLen
    call WriteChar
    jmp NameKeyLoop

NameBackspace:
    cmp robotNameLen, 0
    je NameKeyLoop
    dec robotNameLen
    mov eax, robotNameLen
    add eax, NAME_X
    mov dl, al
    mov dh, NAME_Y
    call Gotoxy
    mov al, ' '
    call WriteChar
    mov eax, robotNameLen
    add eax, NAME_X
    mov dl, al
    mov dh, NAME_Y
    call Gotoxy
    jmp NameKeyLoop

NameDone:
    mov esi, OFFSET robotName
    mov ebx, robotNameLen
    mov BYTE PTR [esi + ebx], 0  ; zero terminator
    cmp robotNameLen, 0
    jne NameExit
    mov esi, OFFSET strDefaultName
    mov edi, OFFSET robotName
NameDefaultLoop:
    mov al, [esi]
    mov [edi], al
    inc esi
    inc edi
    cmp al, 0
    jne NameDefaultLoop  ; JNE: stop after copying the terminator
    mov robotNameLen, 6
NameExit:
    mov showCaret, 0
    mov eax, COLOR_NORMAL
    call SetTextColor

    pop edi
    pop esi
    pop edx
    pop ebx
    pop eax
    ret
NameEntryProc ENDP

; LoadRecordsProc
; Reads robot_records.txt into recordsBuf. Missing file = no records.
; Receives : nothing Returns : recordsLen = bytes of WHOLE records (0 if none)
; Preserves: all registers
LoadRecordsProc PROC
    push eax
    push ebx
    push ecx
    push edx

    mov recordsLen, 0
    mov edx, OFFSET recordFileName
    call OpenInputFile  ; Irvine32: EAX = handle, or -1 if it cannot be opened
    cmp eax, FILE_INVALID
    je LoadDone
    mov fileHandle, eax
    mov edx, OFFSET recordsBuf
    mov ecx, RECORDS_MAX
    call ReadFromFile  ; Irvine32: EAX = bytes read, CF = 1 on error
    jc LoadClose
    xor edx, edx
    mov ecx, RECORD_LEN
    div ecx
    imul eax, RECORD_LEN
    mov recordsLen, eax
LoadClose:
    mov eax, fileHandle
    call CloseFile  ; Irvine32: EAX = handle
LoadDone:
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
LoadRecordsProc ENDP

; SaveRecordProc
; Appends this game's record (name, deliveries, moves, result) to the text file.
; Irvine32 has no "append" mode, so: load the old records, add the new line in
; memory, then rewrite the whole file. Oldest record is dropped after 200.
; Receives : robotName, robotNameLen, deliveriesDone, moveCount
; Returns : saveOk = 1 on success, 0 on failure
; Preserves: all registers
SaveRecordProc PROC
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    mov saveOk, 0
    call LoadRecordsProc

    ; 1) blank the 12-character name field
    mov edi, OFFSET recordLine
    mov ecx, ROBOT_NAME_MAX
    mov al, ' '
SaveBlankLoop:
    mov [edi], al
    inc edi
    loop SaveBlankLoop
    ; 2) copy the name
    mov esi, OFFSET robotName
    mov edi, OFFSET recordLine
    mov ecx, robotNameLen
    cmp ecx, 0
    je SaveNameDone  ; JE: avoid LOOP with ECX = 0
SaveNameLoop:
    mov al, [esi]
    mov [edi], al
    inc esi
    inc edi
    loop SaveNameLoop
SaveNameDone:
    ; 3) deliveries digit
    mov al, '0'
    add al, BYTE PTR deliveriesDone
    mov recordLine[14], al
    ; 4) moves as 3 digits (hundreds, tens, ones by division)
    mov eax, moveCount
    xor edx, edx
    mov ecx, 100
    div ecx
    add al, '0'
    mov recordLine[24], al
    mov eax, edx
    xor edx, edx
    mov ecx, 10
    div ecx
    add al, '0'
    mov recordLine[25], al
    add dl, '0'
    mov recordLine[26], dl

    ; 5) buffer full? drop the oldest record by shifting everything down
    cmp recordsLen, RECORDS_MAX
    jb SaveAppend  ; JB (unsigned): there is still room
    mov esi, OFFSET recordsBuf
    add esi, RECORD_LEN
    mov edi, OFFSET recordsBuf
    mov ecx, RECORDS_MAX - RECORD_LEN
SaveShiftLoop:
    mov al, [esi]
    mov [edi], al
    inc esi
    inc edi
    loop SaveShiftLoop
    mov recordsLen, RECORDS_MAX - RECORD_LEN
SaveAppend:
    ; 6) add the new line at the end of the buffer
    mov esi, OFFSET recordLine
    mov edi, OFFSET recordsBuf
    add edi, recordsLen
    mov ecx, RECORD_LEN
SaveCopyLoop:
    mov al, [esi]
    mov [edi], al
    inc esi
    inc edi
    loop SaveCopyLoop
    add recordsLen, RECORD_LEN

    ; 7) rewrite the file
    mov edx, OFFSET recordFileName
    call CreateOutputFile  ; Irvine32: EAX = handle, or -1 on error
    cmp eax, FILE_INVALID
    je SaveDone
    mov fileHandle, eax
    mov edx, OFFSET recordsBuf
    mov ecx, recordsLen
    call WriteToFile  ; Irvine32: EAX = handle, EDX = buffer, ECX = byte count
    mov eax, fileHandle
    call CloseFile
    mov saveOk, 1
SaveDone:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
SaveRecordProc ENDP

; GameFinishedProc
; Saves the record and shows the final results screen.
; Receives : nothing
; Returns : EAX = ACT_RESTART (R), ACT_MENU (M) or ACT_EXIT (Q / ESC)
; Preserves: everything except EAX
GameFinishedProc PROC
    mov eax, 0
    call SetConsoleVisProc
    push ebx
    push ecx
    push edx
    push esi

    call SaveRecordProc

    mov eax, COLOR_NORMAL
    call SetTextColor
    call Clrscr

    ; double-line box
    mov eax, COLOR_BORDER
    call SetTextColor
    mov dl, MENU_X
    mov dh, 3
    call Gotoxy
    mov al, 0C9h
    call WriteChar
    mov al, 0CDh
    mov ecx, MENU_INNER_W
    call RepeatCharProc
    mov al, 0BBh
    call WriteChar
    mov ebx, 4
ResSideLoop:
    mov dl, MENU_X
    mov dh, bl
    call Gotoxy
    mov al, 0BAh
    call WriteChar
    mov dl, MENU_X + MENU_INNER_W + 1
    mov dh, bl
    call Gotoxy
    mov al, 0BAh
    call WriteChar
    inc ebx
    cmp ebx, 15
    jle ResSideLoop
    mov dl, MENU_X
    mov dh, 16
    call Gotoxy
    mov al, 0C8h
    call WriteChar
    mov al, 0CDh
    mov ecx, MENU_INNER_W
    call RepeatCharProc
    mov al, 0BCh
    call WriteChar

    ; title
    mov eax, COLOR_OK
    call SetTextColor
    mov dl, 40
    mov dh, 5
    mov esi, OFFSET strResTitle
    call PrintAtProc

    ; labels
    mov eax, COLOR_LABEL
    call SetTextColor
    mov dl, 28
    mov dh, 7
    mov esi, OFFSET strResName
    call PrintAtProc
    mov dl, 28
    mov dh, 8
    mov esi, OFFSET strResDeliv
    call PrintAtProc
    mov dl, 28
    mov dh, 9
    mov esi, OFFSET strResMoves
    call PrintAtProc
    mov dl, 28
    mov dh, 10
    mov esi, OFFSET strResResult
    call PrintAtProc

    ; values
    mov eax, COLOR_INFO
    call SetTextColor
    mov dl, 42
    mov dh, 7
    mov esi, OFFSET robotName
    call PrintAtProc
    mov dl, 42
    mov dh, 8
    call Gotoxy
    mov eax, deliveriesDone
    call WriteDec
    mov edx, OFFSET strSlashTotal
    call WriteString
    mov dl, 42
    mov dh, 9
    call Gotoxy
    mov eax, moveCount
    call WriteThreeDigitsProc
    mov eax, COLOR_OK
    call SetTextColor
    mov dl, 42
    mov dh, 10
    mov esi, OFFSET strResDone
    call PrintAtProc

    ; record saved / failed
    cmp saveOk, 0
    je ResNotSaved
    mov eax, COLOR_OK
    call SetTextColor
    mov dl, 28
    mov dh, 12
    mov esi, OFFSET strResSaved
    call PrintAtProc
    jmp ResShowKeys
ResNotSaved:
    mov eax, COLOR_ERROR
    call SetTextColor
    mov dl, 28
    mov dh, 12
    mov esi, OFFSET strResNotSaved
    call PrintAtProc
ResShowKeys:
    mov eax, COLOR_TITLE
    call SetTextColor
    mov dl, 28
    mov dh, 14
    mov esi, OFFSET strResKeys
    call PrintAtProc
    mov eax, COLOR_NORMAL
    call SetTextColor

ResKeyLoop:
    call ReadChar
    cmp al, 'R'
    je ResRestart
    cmp al, 'r'
    je ResRestart
    cmp al, 'M'
    je ResMenu
    cmp al, 'm'
    je ResMenu
    cmp al, 'Q'
    je ResExit
    cmp al, 'q'
    je ResExit
    cmp al, KEY_ESC
    je ResExit
    jmp ResKeyLoop
ResRestart:
    mov eax, ACT_RESTART
    jmp ResDone
ResMenu:
    mov eax, ACT_MENU
    jmp ResDone
ResExit:
    mov eax, ACT_EXIT
ResDone:
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
GameFinishedProc ENDP

; ShowRecordsProc
; Loads robot_records.txt and lists the most recent RECORDS_SHOWN records.
; Receives : nothing Returns : nothing (after any key)
; Preserves: everything except EAX
ShowRecordsProc PROC
    mov eax, 0
    call SetConsoleVisProc
    push eax
    push ebx
    push ecx
    push edx
    push esi

    mov eax, COLOR_NORMAL
    call SetTextColor
    call Clrscr
    mov eax, COLOR_LABEL
    call SetTextColor
    mov dl, 40
    mov dh, 1
    mov esi, OFFSET strRecTitle
    call PrintAtProc

    call LoadRecordsProc
    cmp recordsLen, 0
    jne ShowRecData
    mov eax, COLOR_WARN
    call SetTextColor
    mov dl, 20
    mov dh, 5
    mov esi, OFFSET strRecNone
    call PrintAtProc
    jmp ShowRecWait

ShowRecData:
    mov eax, COLOR_TITLE
    call SetTextColor
    mov dl, 0
    mov dh, 3
    mov esi, OFFSET strRecHeader
    call PrintAtProc

    mov eax, recordsLen
    xor edx, edx
    mov ecx, RECORD_LEN
    div ecx
    mov recTotal, eax
    mov recFirst, 0
    cmp eax, RECORDS_SHOWN
    jle ShowRecStart
    sub eax, RECORDS_SHOWN
    mov recFirst, eax
ShowRecStart:
    mov eax, COLOR_INFO
    call SetTextColor
    mov ebx, recFirst
ShowRecLoop:
    cmp ebx, recTotal
    jge ShowRecNote
    mov eax, ebx
    sub eax, recFirst
    add eax, 4
    mov dh, al
    mov dl, 1
    call Gotoxy
    mov eax, ebx
    inc eax  ; record number (one-based)
    call WriteDec
    mov al, '.'
    call WriteChar
    mov eax, ebx
    sub eax, recFirst
    add eax, 4
    mov dh, al
    mov dl, 7
    call Gotoxy
    mov esi, OFFSET recordsBuf
    mov eax, ebx
    imul eax, RECORD_LEN
    add esi, eax
    mov ecx, RECORD_TEXT_LEN
ShowRecChar:
    mov al, [esi]
    call WriteChar
    inc esi
    loop ShowRecChar
    inc ebx
    jmp ShowRecLoop
ShowRecNote:
    mov eax, COLOR_NORMAL
    call SetTextColor
    mov dl, 2
    mov dh, 18
    mov esi, OFFSET strRecNote
    call PrintAtProc

ShowRecWait:
    mov eax, COLOR_OK
    call SetTextColor
    mov dl, 2
    mov dh, 20
    mov esi, OFFSET strInsBack
    call PrintAtProc
    call ReadChar
    mov eax, COLOR_NORMAL
    call SetTextColor

    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
ShowRecordsProc ENDP

; ROBOT PICTURE, TORCH AND DIRECTION PROCEDURES

; DrawRobotGlyphProc
; Writes the 3-character robot picture at the cursor (the caller has already
; used Gotoxy). The picture is ONE body character '@' plus a 2-character
; torch that points the way the robot faces:
; UP ^@^ DOWN v@v LEFT <=@ RIGHT @=>
; It stays inside the robot's own 3-character cell, so it can never overwrite a
; neighbouring shelf, package or destination tile. Characters marked 1 in
; robotTorchMap use the torch colour, the body uses the robot colour.
; first character of this picture in robotGlyphs = facing * 3
; Receives : EAX = facing 0..3 (FACE_UP .. FACE_RIGHT), cursor already placed
; Returns : nothing Preserves: all registers
DrawRobotGlyphProc PROC
    push eax
    push ebx
    push ecx
    push esi

    mov ebx, eax
    imul ebx, 3
    mov ecx, 0
RobotGlyphLoop:
    mov esi, OFFSET robotTorchMap
    cmp BYTE PTR [esi + ebx], 0
    jne RobotTorchPart
    mov eax, TILE_ROBOT
    jmp RobotSetColor
RobotTorchPart:
    mov eax, TILE_TORCH
RobotSetColor:
    call SetTextColor
    mov esi, OFFSET robotGlyphs
    mov al, [esi + ebx]
    call WriteChar
    inc ebx
    inc ecx
    cmp ecx, 3
    jl RobotGlyphLoop

    pop esi
    pop ecx
    pop ebx
    pop eax
    ret
DrawRobotGlyphProc ENDP

; UpdateDirectionProc
; Prints the robot's facing direction in its dashboard line (only that line).
; Receives : facing (global) Returns : nothing
; Preserves: all registers
UpdateDirectionProc PROC
    push eax
    push edx
    push esi

    mov eax, COLOR_LABEL
    call SetTextColor
    mov eax, facing
    mov esi, OFFSET dirNamePtrs
    mov esi, [esi + eax*4]
    mov dl, SB_VAL_X
    mov dh, SB_DIR_Y
    call PrintAtProc
    mov eax, COLOR_NORMAL
    call SetTextColor

    pop esi
    pop edx
    pop eax
    ret
UpdateDirectionProc ENDP

; SetFacingProc
; Turns the robot toward a direction key. Only if the direction really changes:
; the robot's own tile is redrawn (the 2-character torch now points the new way)
; and the dashboard direction line is updated. Nothing else is touched.
; Receives : EAX = direction action code (ACT_UP .. ACT_RIGHT = 1..4)
; Returns : nothing (EAX is unchanged)
; Preserves: all registers
SetFacingProc PROC
    push eax
    push ebx
    push edx

    dec eax
    cmp eax, facing
    je SetFaceDone
    mov facing, eax
    mov eax, robotRow
    mov ebx, robotCol
    call DrawCellProc
    call UpdateDirectionProc
    call ParkCursorProc
SetFaceDone:
    pop edx
    pop ebx
    pop eax
    ret
SetFacingProc ENDP

; PICTURE MIRROR WINDOW (the picture behind every console screen)

; MirrorInitPtrsProc
; Looks up the kernel32 / gdi32 functions that are called through pointers and
; reads the console handles. Returns EAX = 1 (ok) or 0. Preserves: all else
MirrorInitPtrsProc PROC
    push ebx
    INVOKE GetModuleHandleA, OFFSET szKernel32
    test eax, eax
    jz MipFail
    mov ebx, eax
    INVOKE GetProcAddress, ebx, OFFSET szGetStdHandle
    mov pGetStdHandle, eax
    test eax, eax
    jz MipFail
    INVOKE GetProcAddress, ebx, OFFSET szGetCsbi
    mov pGetCsbi, eax
    test eax, eax
    jz MipFail
    INVOKE GetProcAddress, ebx, OFFSET szReadOutW
    mov pReadOutW, eax
    test eax, eax
    jz MipFail
    INVOKE GetProcAddress, ebx, OFFSET szWriteInA
    mov pWriteInA, eax
    test eax, eax
    jz MipFail
    INVOKE GetProcAddress, ebx, OFFSET szCreateThread
    mov pCreateThread, eax
    test eax, eax
    jz MipFail
    cmp pSetTextColor, 0
    jne MipGdiOk
    INVOKE GetModuleHandleA, OFFSET szGdi32
    test eax, eax
    jz MipFail
    mov ebx, eax
    INVOKE GetProcAddress, ebx, OFFSET szSetTextColor
    mov pSetTextColor, eax
    test eax, eax
    jz MipFail
    INVOKE GetProcAddress, ebx, OFFSET szAlphaBlend
    mov pAlphaBlend, eax
MipGdiOk:
    push -11
    call pGetStdHandle
    mov hOutCon, eax
    push -10
    call pGetStdHandle
    mov hInCon, eax
    mov eax, 1
    jmp MipExit
MipFail:
    xor eax, eax
MipExit:
    pop ebx
    ret
MirrorInitPtrsProc ENDP

; MirrorQuerySizeProc
; Reads the size of the visible console window into mirCols / mirRows / mirCells.
; Returns EAX = 1 (ok) or 0.
MirrorQuerySizeProc PROC
    push ebx
    push ecx
    push edx
    push OFFSET csbiBuf
    push hOutCon
    call pGetCsbi
    test eax, eax
    jz MqsFail
    movzx eax, WORD PTR csbiBuf[10]
    movzx ecx, WORD PTR csbiBuf[14]
    sub ecx, eax
    inc ecx
    movzx eax, WORD PTR csbiBuf[12]
    movzx edx, WORD PTR csbiBuf[16]
    sub edx, eax
    inc edx
    cmp ecx, 20
    jge MqsColsOk1
    mov ecx, 120
MqsColsOk1:
    cmp ecx, MIR_MAXCOLS
    jle MqsColsOk2
    mov ecx, MIR_MAXCOLS
MqsColsOk2:
    cmp edx, 10
    jge MqsRowsOk1
    mov edx, 30
MqsRowsOk1:
    cmp edx, MIR_MAXROWS
    jle MqsRowsOk2
    mov edx, MIR_MAXROWS
MqsRowsOk2:
    mov mirCols, ecx
    mov mirRows, edx
    mov eax, ecx
    imul eax, edx
    mov mirCells, eax
    mov eax, 1
    jmp MqsExit
MqsFail:
    xor eax, eax
MqsExit:
    pop edx
    pop ecx
    pop ebx
    ret
MirrorQuerySizeProc ENDP

; MirrorReadProc
; Reads the visible console cells (character + colour attribute) into mirCur and
; stores the caret position / visibility in the extra element behind them.
; Returns EAX = 1 (ok) or 0.
MirrorReadProc PROC
    push ebx
    push ecx
    push edx
    push edi

    push OFFSET csbiBuf
    push hOutCon
    call pGetCsbi
    test eax, eax
    jz MrFail
    movzx eax, WORD PTR csbiBuf[10]
    mov mirLeft, eax
    movzx ecx, WORD PTR csbiBuf[12]
    mov mirTop, ecx
    mov edx, ecx
    shl edx, 16
    or edx, eax
    mov readRegion[0], edx
    add eax, mirCols
    dec eax
    add ecx, mirRows
    dec ecx
    shl ecx, 16
    or ecx, eax
    mov readRegion[4], ecx

    ; caret: bit 16 = visible, bits 0-7 = column, bits 8-15 = row
    xor ebx, ebx
    cmp showCaret, 0
    je MrStoreCaret
    movzx eax, WORD PTR csbiBuf[4]
    sub eax, mirLeft
    movzx edx, WORD PTR csbiBuf[6]
    sub edx, mirTop
    cmp eax, 0
    jl MrStoreCaret
    cmp eax, mirCols
    jge MrStoreCaret
    cmp edx, 0
    jl MrStoreCaret
    cmp edx, mirRows
    jge MrStoreCaret
    shl edx, 8
    or eax, edx
    or eax, 10000h
    mov ebx, eax
MrStoreCaret:
    mov edi, mirCells
    mov mirCur[edi*4], ebx

    ; ReadConsoleOutputW(hOut, buffer, size, coord 0,0, region)
    mov eax, mirRows
    shl eax, 16
    or eax, mirCols  ; COORD: X = columns, Y = rows
    push OFFSET readRegion
    push 0
    push eax
    push OFFSET mirCur
    push hOutCon
    call pReadOutW
    jmp MrExit
MrFail:
    xor eax, eax
MrExit:
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret
MirrorReadProc ENDP

; MirFillCellProc (helper)
; Fills the character cell at pixel (mX, mY) of the frame with a brush.
; Receives : EAX = brush handle Preserves: everything except EAX, ECX, EDX
MirFillCellProc PROC
    push ebx
    mov ebx, eax
    mov eax, mX
    mov mirRect[0], eax
    add eax, MIR_CW
    mov mirRect[8], eax
    mov eax, mY
    mov mirRect[4], eax
    add eax, MIR_CH
    mov mirRect[12], eax
    INVOKE FillRect, hMirFrameDC, OFFSET mirRect, ebx
    pop ebx
    ret
MirFillCellProc ENDP

; MirrorDrawFrameProc
; Builds one frame off-screen: the dimmed picture, then every console cell:
; background colour 0 (black) -> transparent, the picture shows through
; any other background colour -> solid coloured cell
; full block characters -> solid cell in the text colour (shelves)
; other characters -> drawn with the Consolas font in the text colour
; plus the caret on the name-entry screen.
MirrorDrawFrameProc PROC USES ebx esi edi
    INVOKE BitBlt, hMirFrameDC, 0, 0, mirWinW, mirWinH, hMirBgDC, 0, 0, BG_ROP_COPY
    mov lastFg, -1
    mov esi, OFFSET mirCur
    xor ebx, ebx
MdRow:
    xor edi, edi
MdCol:
    movzx eax, WORD PTR [esi]
    mov mChar, eax
    movzx edx, WORD PTR [esi + 2]
    add esi, 4
    mov ecx, edx
    and ecx, 0Fh
    mov mFg, ecx
    shr edx, 4
    and edx, 0Fh
    mov mBg, edx
    mov eax, edi
    imul eax, MIR_CW
    mov mX, eax
    mov eax, ebx
    imul eax, MIR_CH
    mov mY, eax

    cmp mBg, 0
    je MdNoBg  ; JE: black background = transparent
    mov edx, mBg
    mov eax, mirBrush[edx*4]
    call MirFillCellProc
MdNoBg:
    mov eax, mChar
    cmp eax, 20h
    je MdNext
    cmp eax, 0
    je MdNext
    cmp eax, 2588h
    jne MdText
    mov edx, mFg
    mov eax, mirBrush[edx*4]
    call MirFillCellProc
    jmp MdNext
MdText:
    mov eax, mFg
    cmp eax, lastFg
    je MdDraw
    mov lastFg, eax
    push mirPalette[eax*4]
    push hMirFrameDC
    call pSetTextColor
MdDraw:
    INVOKE TextOutW, hMirFrameDC, mX, mY, OFFSET mChar, 1
MdNext:
    inc edi
    cmp edi, mirCols
    jl MdCol
    inc ebx
    cmp ebx, mirRows
    jl MdRow

    ; caret (a steady yellow bar under the cursor cell)
    mov edx, mirCells
    mov eax, mirCur[edx*4]
    test eax, 10000h
    jz MdDone
    movzx ecx, al
    movzx edx, ah
    imul ecx, MIR_CW
    imul edx, MIR_CH
    add edx, MIR_CH - 3
    mov mirRect[0], ecx
    add ecx, MIR_CW
    mov mirRect[8], ecx
    mov mirRect[4], edx
    add edx, 3
    mov mirRect[12], edx
    INVOKE FillRect, hMirFrameDC, OFFSET mirRect, mirBrush[14*4]
MdDone:
    ret
MirrorDrawFrameProc ENDP

; MirrorPresentProc
; Copies the finished off-screen frame to the mirror window in ONE step.
MirrorPresentProc PROC USES ebx
    INVOKE GetDC, hMirWnd
    mov ebx, eax
    test ebx, ebx
    jz MpDone
    INVOKE BitBlt, ebx, 0, 0, mirWinW, mirWinH, hMirFrameDC, 0, 0, BG_ROP_COPY
    INVOKE ReleaseDC, hMirWnd, ebx
MpDone:
    ret
MirrorPresentProc ENDP

; MirrorTickProc (called about 60 times a second by the window timer)
; Reads the console. A frame is drawn only when the console contents have been
; the SAME on two consecutive reads (so a half-built screen is never shown) and
; differ from what is on screen.
MirrorTickProc PROC USES ebx esi edi
    cmp mirActive, 0
    je MtDone
    call MirrorReadProc
    test eax, eax
    jz MtDone
    cld
    mov ecx, mirCells
    inc ecx  ; cells + caret element
    mov esi, OFFSET mirCur
    mov edi, OFFSET mirPrev
    repe cmpsd
    je MtStable
    mov ecx, mirCells
    inc ecx
    mov esi, OFFSET mirCur
    mov edi, OFFSET mirPrev
    rep movsd
    jmp MtDone
MtStable:
    cmp mirForce, 0
    jne MtDraw
    mov ecx, mirCells
    inc ecx
    mov esi, OFFSET mirCur
    mov edi, OFFSET mirShown
    repe cmpsd
    je MtDone
MtDraw:
    call MirrorDrawFrameProc
    cld
    mov ecx, mirCells
    inc ecx
    mov esi, OFFSET mirCur
    mov edi, OFFSET mirShown
    rep movsd
    mov mirForce, 0
    call MirrorPresentProc
MtDone:
    ret
MirrorTickProc ENDP

; MirInjectKeyProc (stdcall parameters)
; Puts one key-down event into the console input buffer so that the game's
; ReadKey / ReadChar receive keys typed into the mirror window.
MirInjectKeyProc PROC USES ebx esi edi, vk:DWORD, scan:DWORD, chr:DWORD
    mov inRec[0], 1
    mov inRec[4], 1
    mov eax, vk
    shl eax, 16
    or eax, 1
    mov inRec[8], eax
    mov eax, chr
    shl eax, 16
    or eax, scan  ; scan code | character << 16
    mov inRec[12], eax
    mov inRec[16], 0
    push OFFSET inWritten
    push 1
    push OFFSET inRec
    push hInCon
    call pWriteInA
    ret
MirInjectKeyProc ENDP

; MirWndProc (window procedure of the mirror window; called by Windows)
MirWndProc PROC USES ebx esi edi, hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
    mov eax, uMsg
    cmp eax, MW_TIMER
    je MwTimer
    cmp eax, MW_PAINT
    je MwPaint
    cmp eax, MW_ERASEBKGND
    je MwErase
    cmp eax, MW_KEYDOWN
    je MwKeyDown
    cmp eax, MW_CHAR
    je MwChar
    cmp eax, MW_RESET
    je MwReset
    cmp eax, MW_CLOSE
    je MwClose
    cmp eax, MW_DESTROY
    je MwDestroy
MwDefault:
    INVOKE DefWindowProcA, hWnd, uMsg, wParam, lParam
    ret

MwTimer:
    call MirrorTickProc
    xor eax, eax
    ret

MwErase:
    mov eax, 1
    ret

MwPaint:
    INVOKE BeginPaint, hWnd, OFFSET mirPs
    mov ebx, eax
    INVOKE BitBlt, ebx, 0, 0, mirWinW, mirWinH, hMirFrameDC, 0, 0, BG_ROP_COPY
    INVOKE EndPaint, hWnd, OFFSET mirPs
    xor eax, eax
    ret

MwReset:
    mov mirForce, 1
    INVOKE BitBlt, hMirFrameDC, 0, 0, mirWinW, mirWinH, hMirBgDC, 0, 0, BG_ROP_COPY
    call MirrorPresentProc
    xor eax, eax
    ret

MwKeyDown:  ; arrow keys (they produce no WM_CHAR)
    mov eax, wParam
    cmp eax, 25h
    jb MwDefault
    cmp eax, 28h
    ja MwDefault
    mov edx, lParam
    shr edx, 16
    and edx, 0FFh  ; scan code
    INVOKE MirInjectKeyProc, eax, edx, 0
    xor eax, eax
    ret

MwChar:
    mov eax, wParam
    mov ecx, eax
    cmp ecx, 'a'
    jb MwVkDone
    cmp ecx, 'z'
    ja MwVkDone
    sub ecx, 20h
MwVkDone:
    mov edx, lParam
    shr edx, 16
    and edx, 0FFh  ; scan code
    INVOKE MirInjectKeyProc, ecx, edx, eax
    xor eax, eax
    ret

MwClose:
    INVOKE ExitProcess, 0
    xor eax, eax
    ret

MwDestroy:
    INVOKE PostQuitMessage, 0
    xor eax, eax
    ret
MirWndProc ENDP

; MirrorBuildResourcesProc
; Creates the off-screen frame, the dimmed picture and the 16 colour brushes
; and the font. Returns EAX = 1 (ok) or 0.
MirrorBuildResourcesProc PROC USES ebx esi edi
    LOCAL hScr:DWORD, hTmp:DWORD, hTmpOld:DWORD
    LOCAL hOvDC:DWORD, hOvBmp:DWORD, hOvOld:DWORD

    INVOKE GetDC, 0
    mov hScr, eax
    test eax, eax
    jz MbrFail

    INVOKE CreateCompatibleDC, hScr
    mov hMirFrameDC, eax
    INVOKE CreateCompatibleBitmap, hScr, mirWinW, mirWinH
    mov hMirFrameBmp, eax
    INVOKE SelectObject, hMirFrameDC, hMirFrameBmp

    INVOKE CreateCompatibleDC, hScr
    mov hMirBgDC, eax
    INVOKE CreateCompatibleBitmap, hScr, mirWinW, mirWinH
    mov hMirBgBmp, eax
    INVOKE SelectObject, hMirBgDC, hMirBgBmp

    ; the picture, stretched to the window
    INVOKE CreateCompatibleDC, hScr
    mov hTmp, eax
    INVOKE SelectObject, hTmp, hBgBitmap
    mov hTmpOld, eax
    INVOKE SetStretchBltMode, hMirBgDC, BG_HALFTONE
    INVOKE StretchBlt, hMirBgDC, 0, 0, mirWinW, mirWinH, hTmp, 0, 0, bmpInfo[4], bmpInfo[8], BG_ROP_COPY
    INVOKE SelectObject, hTmp, hTmpOld
    INVOKE DeleteDC, hTmp

    ; dark veil over the picture so that the text stays readable
    cmp pAlphaBlend, 0
    je MbrNoDim
    INVOKE CreateCompatibleDC, hScr
    mov hOvDC, eax
    INVOKE CreateCompatibleBitmap, hScr, mirWinW, mirWinH
    mov hOvBmp, eax
    INVOKE SelectObject, hOvDC, hOvBmp
    mov hOvOld, eax
    INVOKE FillBoxProc, hOvDC, 0, 0, mirWinW, mirWinH, 0
    push MIR_DIM_ALPHA  ; AlphaBlend(bg, 0, 0, W, H, veil, 0, 0, W, H, alpha)
    push mirWinH
    push mirWinW
    push 0
    push 0
    push hOvDC
    push mirWinH
    push mirWinW
    push 0
    push 0
    push hMirBgDC
    call pAlphaBlend
    INVOKE SelectObject, hOvDC, hOvOld
    INVOKE DeleteObject, hOvBmp
    INVOKE DeleteDC, hOvDC
MbrNoDim:

    ; one solid brush per console colour
    xor esi, esi
MbrBrushLoop:
    INVOKE CreateSolidBrush, mirPalette[esi*4]
    mov mirBrush[esi*4], eax
    inc esi
    cmp esi, 16
    jl MbrBrushLoop

    ; font and text mode of the frame
    INVOKE CreateFontA, -16, 0, 0, 0, 400, 0, 0, 0, 1, 0, 0, 5, 0, OFFSET szMirFont
    INVOKE SelectObject, hMirFrameDC, eax
    INVOKE SetBkMode, hMirFrameDC, 1

    INVOKE BitBlt, hMirFrameDC, 0, 0, mirWinW, mirWinH, hMirBgDC, 0, 0, BG_ROP_COPY
    INVOKE ReleaseDC, 0, hScr
    mov eax, 1
    ret
MbrFail:
    xor eax, eax
    ret
MirrorBuildResourcesProc ENDP

; MirrorThreadProc
; Runs in its own thread (created by MirrorShowProc): creates the mirror window
; and its message loop, so the game thread never has to handle window messages.
; stdcall thread procedure with one parameter (unused).
MirrorThreadProc PROC USES ebx esi edi, lpParam:DWORD
    call MirrorQuerySizeProc
    test eax, eax
    jz MtpFail
    mov eax, mirCols
    imul eax, MIR_CW
    mov mirWinW, eax
    mov eax, mirRows
    imul eax, MIR_CH
    mov mirWinH, eax

    call MirrorBuildResourcesProc
    test eax, eax
    jz MtpFail

    INVOKE GetModuleHandleA, 0
    mov hInst, eax
    mov mirWc[0], 48  ; WNDCLASSEX
    mov mirWc[4], 0
    mov mirWc[8], OFFSET MirWndProc
    mov mirWc[12], 0
    mov mirWc[16], 0
    mov eax, hInst
    mov mirWc[20], eax
    mov mirWc[24], 0
    INVOKE LoadCursorA, 0, 32512
    mov mirWc[28], eax
    mov mirWc[32], 0
    mov mirWc[36], 0
    mov mirWc[40], OFFSET szMirClass
    mov mirWc[44], 0
    INVOKE RegisterClassExA, OFFSET mirWc
    test eax, eax
    jz MtpFail

    mov rcMirAdj[0], 0
    mov rcMirAdj[4], 0
    mov eax, mirWinW
    mov rcMirAdj[8], eax
    mov eax, mirWinH
    mov rcMirAdj[12], eax
    INVOKE AdjustWindowRect, OFFSET rcMirAdj, MIR_STYLE, 0
    mov eax, rcMirAdj[8]
    sub eax, rcMirAdj[0]
    mov mirOuterW, eax
    mov eax, rcMirAdj[12]
    sub eax, rcMirAdj[4]
    mov mirOuterH, eax
    INVOKE GetSystemMetrics, 0
    sub eax, mirOuterW
    sar eax, 1
    jns MtpXok
    xor eax, eax
MtpXok:
    mov esi, eax
    INVOKE GetSystemMetrics, 1
    sub eax, mirOuterH
    sar eax, 1
    jns MtpYok
    xor eax, eax
MtpYok:
    mov edi, eax

    INVOKE CreateWindowExA, WIN_EXSTYLE, OFFSET szMirClass, OFFSET szMirTitle, MIR_STYLE, esi, edi, mirOuterW, mirOuterH, 0, 0, hInst, 0
    test eax, eax
    jz MtpFail
    mov ebx, eax
    INVOKE SetTimer, ebx, 1, MIR_TIMER_MS, 0
    mov hMirWnd, ebx

MtpLoop:
    INVOKE GetMessageA, OFFSET mirMsg, 0, 0, 0
    cmp eax, 0
    jle MtpEnd
    INVOKE TranslateMessage, OFFSET mirMsg
    INVOKE DispatchMessageA, OFFSET mirMsg
    jmp MtpLoop
MtpEnd:
    xor eax, eax
    ret
MtpFail:
    mov mirrorFailed, 1
    xor eax, eax
    ret
MirrorThreadProc ENDP

; MirrorShowProc
; Shows the picture mirror window (creating it, with its thread, the first time)
; and brings it to the front, so every console screen appears on the picture.
; Does nothing (the game stays in the plain console) if there is no picture or
; the mirror cannot start. Preserves: all registers
MirrorShowProc PROC
    push eax
    push ecx
    push edx

    cmp hBgBitmap, 0
    je MsExit
    cmp mirrorFailed, 0
    jne MsExit
    cmp hMirWnd, 0
    jne MsShow

    call MirrorInitPtrsProc
    test eax, eax
    jz MsFail
    push OFFSET mirThreadId
    push 0
    push 0
    push OFFSET MirrorThreadProc
    push 0
    push 0
    call pCreateThread
    test eax, eax
    jz MsFail
    mov hMirThread, eax
    mov ecx, 200
MsWait:
    cmp hMirWnd, 0
    jne MsShow
    cmp mirrorFailed, 0
    jne MsExit
    push ecx
    mov eax, 20
    call Delay
    pop ecx
    dec ecx
    jnz MsWait
MsFail:
    mov mirrorFailed, 1
    jmp MsExit

MsShow:
    mov mirForce, 1
    mov mirActive, 1
    INVOKE ShowWindow, hMirWnd, 5
    INVOKE SwitchToThisWindow, hMirWnd, 1
    INVOKE SetForegroundWindow, hMirWnd
    INVOKE SetWindowPos, hMirWnd, -2, 0, 0, 0, 0, 3  ; HWND_NOTOPMOST: normal window again
MsExit:
    pop edx
    pop ecx
    pop eax
    ret
MirrorShowProc ENDP

; MirrorHideProc
; Hides the mirror window (the picture menu or the text menu is shown instead)
; and resets it to the plain picture so no old screen flashes up next time.
; Preserves: all registers
MirrorHideProc PROC
    push eax
    push ecx
    push edx
    cmp hMirWnd, 0
    je MhExit
    mov mirActive, 0
    INVOKE SendMessageA, hMirWnd, MW_RESET, 0, 0
    INVOKE ShowWindow, hMirWnd, 0
MhExit:
    pop edx
    pop ecx
    pop eax
    ret
MirrorHideProc ENDP

END main
