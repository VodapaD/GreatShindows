; ==============================================================================
;                        НАСТРОЙКИ И ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
; ==============================================================================

; --- Системные настройки ---
CoordMode "Mouse", "Screen"
SetWinDelay -1

; --- Настройки анимации центрирования окна (Win + S) ---
Duration := 300          ; Длительность анимации в миллисекундах (0.3 сек)

; --- Настройки горячего угла ---
CornerSize := 3          ; Совсем маленький размер, чтобы не мешать в приложениях
HoverDelay := 50         ; Задержка (мс), чтобы не было ложных срабатываний

; --- Настройки скролинга ---
scrollThreshold := 5     ; Порог смещения для одного шага скролинга

; --- Глобальные переменные скролинга ---
global isScrolling := false
global startX := 0
global startY := 0
global virtualY := 0     ; Накопленное смещение

; ==============================================================================


; --- НАСТРОЙКА ГРУППЫ БРАУЗЕРОВ ---
; Мы добавляем в группу "WebBrowsers" все популярные браузеры.
; Скрипт будет искать любое окно из этого списка.
GroupAdd "WebBrowsers", "ahk_exe chrome.exe"      ; Google Chrome
GroupAdd "WebBrowsers", "ahk_exe msedge.exe"      ; Microsoft Edge
GroupAdd "WebBrowsers", "ahk_exe firefox.exe"     ; Mozilla Firefox
GroupAdd "WebBrowsers", "ahk_exe opera.exe"       ; Opera
GroupAdd "WebBrowsers", "ahk_exe browser.exe"     ; Yandex Browser
GroupAdd "WebBrowsers", "ahk_exe brave.exe"       ; Brave
GroupAdd "WebBrowsers", "ahk_exe zen.exe"       ; Brave

; ==============================================================================


; --- ЗАПУСК ТЕРМИНАЛА ---
#t::
{
    ; Проверяем, запущен ли уже Терминал
    if WinExist("ahk_exe WindowsTerminal.exe")
    {
        ; Если да — делаем его активным
        WinActivate
    }
    else
    {
        ; Если нет — запускаем новый
        Run "wt.exe"
        if WinWait("ahk_exe WindowsTerminal.exe",, 3)
            WinActivate
    }
}

; --- Win + B: ОТКРЫТИЕ БРАУЗЕРА ПО УМОЛЧАНИЮ ---
#b::
{
    ; 1. Проверяем, есть ли уже открытое окно из нашей группы "WebBrowsers"
    if WinExist("ahk_group WebBrowsers")
    {
        ; Если есть — переключаемся на самое последнее активное
        WinActivate
    }
    else
    {
        ; 2. Если браузера нет — нажимаем "Домой", чтобы система открыла браузер по умолчанию
        Send "{Browser_Home}"
    }
}

; --- Win + C: ЗАКРЫТИЕ АКТИВНОГО ОКНА ---
#c::
{
    WinClose "A"  ; "A" означает Active window (Активное окно)
}

; --- Win + S: ПЕРЕМЕЩЕНИЕ АКТИВНОГО ОКНА В ЦЕНТР ЭКРАНА ---
#s::
{
    hwnd := WinExist("A")
    if !hwnd || WinGetMinMax(hwnd) = 1
        return

    WinGetPos &StartX, &StartY, &W, &H, hwnd
    TargetX := (A_ScreenWidth - W) / 2
    TargetY := (A_ScreenHeight - H) / 2

    ; Получаем начальное время в мс
    StartTime := A_TickCount
    
    Loop
    {
        ; Вычисляем, сколько времени прошло от 0.0 до 1.0
        Elapsed := A_TickCount - StartTime
        T := Elapsed / Duration
        
        if (T >= 1)
            break

        ; Функция плавности (Ease-Out Quart): окно тормозит к концу
        ; Формула: 1 - (1 - t)^4
        EasedT := 1 - ((1 - T) ** 4)

        ; Новые координаты
        NewX := StartX + (TargetX - StartX) * EasedT
        NewY := StartY + (TargetY - StartY) * EasedT

        WinMove Integer(NewX), Integer(NewY),,, hwnd
        
        ; Минимально возможная пауза. DllCall точнее обычного Sleep.
        DllCall("Sleep", "UInt", 1) 
    }

    ; Финальная точка
    WinMove Integer(TargetX), Integer(TargetY),,, hwnd
}

; --- ОТКРЫТИЕ ОБЗОРА ПРИ НАВЕДЕНИИ КУРСОРА НА ВЕРХНИЙ ЛЕВЫЙ УГОЛ ЭКРАНА ---

SetTimer CheckMouseCorner, 10

CheckMouseCorner()
{
    static IsTriggered := false
    static StartHoverTime := 0
    
    MouseGetPos &MouseX, &MouseY
    
    ; Проверяем строго верхний левый угол
    if (MouseX <= CornerSize && MouseY <= CornerSize)
    {
        ; Проверяем, не открыто ли полноэкранное окно (кроме случая, когда Win+Tab уже активен или это рабочий стол)
        if (!IsWinTabActive() && !IsDesktopActive() && IsFullscreenAppActive())
        {
            ; Сбрасываем состояние и не активируем
            StartHoverTime := 0
            IsTriggered := false
            return
        }
        
        ; Если мы только что зашли в угол
        if (StartHoverTime == 0)
        {
            StartHoverTime := A_TickCount
        }
        
        ; Если время удержания вышло и мы еще не активировали Win+Tab
        if (!IsTriggered && (A_TickCount - StartHoverTime >= HoverDelay))
        {
            Send "#{Tab}"
            IsTriggered := true ; Блокируем повторный запуск, пока не уберем мышь
        }
    }
    else
    {
        ; Сбрасываем всё, как только мышь вышла из угла
        StartHoverTime := 0
        IsTriggered := false
    }
}

; Проверяет, активен ли рабочий стол
IsDesktopActive()
{
    try {
        activeClass := WinGetClass("A")
        activeProcess := WinGetProcessName("A")
        
        ; Рабочий стол имеет класс "WorkerW" или "Progman"
        ; Процесс - explorer.exe
        if ((activeClass = "WorkerW" || activeClass = "Progman") && activeProcess = "explorer.exe")
            return true
            
        ; Также проверяем на Проводник (открытые папки)
        if (activeClass = "CabinetWClass" && activeProcess = "explorer.exe")
            return true
    }
    return false
}

; Проверяет, активен ли Win+Tab (Task View)
IsWinTabActive()
{
    try {
        ; Проверяем класс активного окна
        activeClass := WinGetClass("A")
        ; Task View имеет класс "Windows.UI.Core.CoreWindow" или "MultitaskingViewFrame"
        if (InStr(activeClass, "MultitaskingViewFrame") || InStr(activeClass, "XamlExplorerHostIslandWindow"))
            return true
    }
    return false
}

; Проверяет, активно ли полноэкранное приложение
IsFullscreenAppActive()
{
    try {
        ; Получаем handle активного окна
        hwnd := WinGetID("A")
        
        ; Получаем размеры окна
        WinGetPos &winX, &winY, &winWidth, &winHeight, "ahk_id " hwnd
        
        ; Получаем размеры монитора
        MonitorGet MonitorGetPrimary(), &monLeft, &monTop, &monRight, &monBottom
        monWidth := monRight - monLeft
        monHeight := monBottom - monTop
        
        ; Проверяем, занимает ли окно весь экран
        ; (с небольшой погрешностью в 5 пикселей)
        if (Abs(winX - monLeft) <= 5 
            && Abs(winY - monTop) <= 5 
            && Abs(winWidth - monWidth) <= 10 
            && Abs(winHeight - monHeight) <= 10)
        {
            return true
        }
    }
    return false
}

; === СВОРАЧИВАНИЕ И РАЗВОРАЧИВАНИЕ ОКОН ===

; Win + PageUp - Развернуть активное окно на весь экран
#PgUp::
{
    try {
        WinMaximize "A"
    }
}

; Win + PageDown - Свернуть активное окно
#PgDn::
{
    try {
        WinMinimize "A"
    }
}

; === ПЛАВНЫЙ СКРОЛИНГ НА ЗАЖАТИЕ КОЛЕСИКА МЫШКИ ===

MButton::
{
    global isScrolling, startX, startY, virtualY
    MouseGetPos(&startX, &startY)
    virtualY := 0  ; Сброс накопленного смещения
    isScrolling := true
    SetTimer(ScrollCheck, 10)
}

MButton Up::
{
    global isScrolling
    isScrolling := false
    SetTimer(ScrollCheck, 0)
}

ScrollCheck()
{
    global isScrolling, startX, startY, virtualY
    
    if (!isScrolling)
        return
    
    MouseGetPos(&currentX, &currentY)
    
    ; Накапливаем смещение относительно стартовой позиции
    delta := currentY - startY
    virtualY += delta
    
    ; Меньший порог для более плавной прокрутки
    
    
    if (Abs(virtualY) >= scrollThreshold)
    {
        ; Вычисляем количество шагов
        scrollSteps := Floor(Abs(virtualY) / scrollThreshold)
        
        Loop scrollSteps
        {
            if (virtualY > 0)
                Send("{WheelDown}")
            else
                Send("{WheelUp}")
        }
        
        ; Уменьшаем виртуальное смещение на использованное количество
        virtualY := Mod(virtualY, scrollThreshold) * (virtualY > 0 ? 1 : -1)
    }
    
    ; Возвращаем курсор на место
    MouseMove(startX, startY)
}

; Блокируем физическое движение мыши при зажатом колесике
#HotIf isScrolling
*Up::return
*Down::return
*Left::return
*Right::return
#HotIf

; ==============================================================================
; Win + ЛКМ: Перемещение (Используем SysCommand 0xF012)
; ==============================================================================
#LButton::{
    MouseGetPos &startX, &startY, &winId
    
    if WinGetClass(winId) = "WorkerW" || WinGetClass(winId) = "Progman"
        return

    winId := WinExist("ahk_id " winId)
    topWin := DllCall("GetAncestor", "Ptr", winId, "UInt", 2, "Ptr")
    if topWin
        winId := topWin

    if WinGetMinMax(winId) = 1
        WinRestore winId
    WinActivate winId

    WinGetPos &winX, &winY,,,winId

    SetWinDelay -1
    While GetKeyState("LButton", "P") {
        MouseGetPos &curX, &curY
        dx := curX - startX
        dy := curY - startY
        WinMove winX + dx, winY + dy,,, winId
        Sleep 1
    }
}

; ==============================================================================
; Win + ПКМ: Изменение размера (4 области)
; ==============================================================================
#RButton::{
    MouseGetPos &startX, &startY, &winId
    
    if WinGetClass(winId) = "WorkerW" || WinGetClass(winId) = "Progman"
        return

    WinActivate winId
    if WinGetMinMax(winId) = 1
        WinRestore winId

    WinGetPos &winX, &winY, &winW, &winH, winId
    
    ; Определяем, в каком квадранте был клик
    ; 1 | 2
    ; --+--
    ; 3 | 4
    relX := startX - winX
    relY := startY - winY
    
    isLeft := (relX < winW / 2)
    isTop  := (relY < winH / 2)

    ; Основной цикл изменения размера
    While GetKeyState("RButton", "P") {
        MouseGetPos &curX, &curY
        dx := curX - startX
        dy := curY - startY
        
        ; Сбрасываем переменные к текущим (чтобы не накапливать ошибки)
        newX := winX
        newY := winY
        newW := winW
        newH := winH

        ; Логика для 4 углов:
        
        ; Если слева - меняем X и Ширину
        if isLeft {
            newW := winW - dx
            newX := winX + dx
        } else {
            ; Если справа - меняем только Ширину
            newW := winW + dx
        }

        ; Если сверху - меняем Y и Высоту
        if isTop {
            newH := winH - dy
            newY := winY + dy
        } else {
            ; Если снизу - меняем только Высоту
            newH := winH + dy
        }
        
        ; Применяем, если размер не ушел в минус
        if (newW > 10 && newH > 10)
            WinMove newX, newY, newW, newH, winId
            
        Sleep 1
    }
}
