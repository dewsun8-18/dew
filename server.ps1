# ==============================================================================
# Server Backend for Meatball Store Dashboard & AI Vision (Google Gemini API)
# Zero-Install Native PowerShell Web Server (PowerShell 5.1+ / Windows)
# ==============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
$utf8BOM = New-Object System.Text.UTF8Encoding($true)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }
Set-Location $scriptDir

# Load Config
$configFile = Join-Path $scriptDir "config.json"
function Get-AppConfig {
    if (Test-Path $configFile) {
        $raw = [System.IO.File]::ReadAllText($configFile, [System.Text.Encoding]::UTF8)
        return ($raw | ConvertFrom-Json)
    }
    return [PSCustomObject]@{
        geminiApiKey = ""
        model = "gemini-3.5-flash-lite"
        port = 8080
    }
}

$config = Get-AppConfig
$port = if ($config.port) { $config.port } else { 8080 }

# Start HttpListener
$listener = New-Object System.Net.HttpListener
$prefix = "http://localhost:$port/"
$listener.Prefixes.Add($prefix)

try {
    $listener.Start()
    Write-Host "=================================================================" -ForegroundColor Green
    Write-Host " Meatball Store Dashboard & AI Vision Server Started" -ForegroundColor Yellow
    Write-Host " URL: $prefix" -ForegroundColor Cyan
    Write-Host " Press Ctrl + C to stop" -ForegroundColor Gray
    Write-Host "=================================================================" -ForegroundColor Green
} catch {
    Write-Host "Error starting server on port $port : $_" -ForegroundColor Red
    exit 1
}

# Helper to send response
function Send-Response {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [int]$StatusCode,
        [string]$ContentType,
        [byte[]]$Data
    )
    $Response.StatusCode = $StatusCode
    $Response.ContentType = $ContentType
    $Response.AddHeader("Access-Control-Allow-Origin", "*")
    $Response.AddHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    $Response.AddHeader("Access-Control-Allow-Headers", "Content-Type, Authorization")
    $Response.ContentLength64 = $Data.Length
    $Response.OutputStream.Write($Data, 0, $Data.Length)
    $Response.OutputStream.Close()
}

function Send-JsonResponse {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [int]$StatusCode,
        [object]$Object
    )
    $json = $Object | ConvertTo-Json -Depth 10 -Compress
    $bytes = $utf8NoBOM.GetBytes($json)
    Send-Response -Response $Response -StatusCode $StatusCode -ContentType "application/json; charset=utf-8" -Data $bytes
}

# Thai month names mapping
$thaiMonths = @{
    1 = "01_มค"
    2 = "02_กพ"
    3 = "03_มีค"
    4 = "04_เมย"
    5 = "05_พค"
    6 = "06_มิย"
    7 = "07_กค"
    8 = "08_สค"
    9 = "09_กย"
    10 = "10_ตค"
    11 = "11_พย"
    12 = "12_ธค"
}

# Event loop
while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $httpMethod = $request.HttpMethod
        $path = $request.Url.AbsolutePath
        $decodedPath = [System.Uri]::UnescapeDataString($path)

        # Handle CORS OPTIONS Preflight
        if ($httpMethod -eq "OPTIONS") {
            $response.StatusCode = 200
            $response.AddHeader("Access-Control-Allow-Origin", "*")
            $response.AddHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            $response.AddHeader("Access-Control-Allow-Headers", "Content-Type, Authorization")
            $response.OutputStream.Close()
            continue
        }

        # -------------------------------------------------------------
        # API ROUTE: GET /api/config
        # -------------------------------------------------------------
        if ($httpMethod -eq "GET" -and $decodedPath -eq "/api/config") {
            $cfg = Get-AppConfig
            $hasKey = (-not [string]::IsNullOrWhiteSpace($cfg.geminiApiKey))
            $maskedKey = ""
            if ($hasKey) {
                if ($cfg.geminiApiKey.Length -gt 8) {
                    $maskedKey = $cfg.geminiApiKey.Substring(0, 4) + "..." + $cfg.geminiApiKey.Substring($cfg.geminiApiKey.Length - 4)
                } else {
                    $maskedKey = "****"
                }
            }
            Send-JsonResponse -Response $response -StatusCode 200 -Object @{
                hasApiKey = $hasKey
                maskedKey = $maskedKey
                model = $cfg.model
                port = $cfg.port
            }
            continue
        }

        # -------------------------------------------------------------
        # API ROUTE: POST /api/config
        # -------------------------------------------------------------
        if ($httpMethod -eq "POST" -and $decodedPath -eq "/api/config") {
            $reader = New-Object System.IO.StreamReader($request.InputStream, $request.ContentEncoding)
            $bodyText = $reader.ReadToEnd()
            $body = $bodyText | ConvertFrom-Json
            $cfg = Get-AppConfig
            if ($body.apiKey -and -not $body.apiKey.Contains("...") -and -not $body.apiKey.Contains("***")) {
                $cfg.geminiApiKey = $body.apiKey.Trim()
            }
            if ($body.model) { $cfg.model = $body.model.Trim() }
            $savedJson = $cfg | ConvertTo-Json -Depth 5
            [System.IO.File]::WriteAllText($configFile, $savedJson, [System.Text.Encoding]::UTF8)
            Send-JsonResponse -Response $response -StatusCode 200 -Object @{ success = $true; message = "บันทึกการตั้งค่าเรียบร้อยแล้ว" }
            continue
        }

        # -------------------------------------------------------------
        # API ROUTE: POST /api/test-key
        # -------------------------------------------------------------
        if ($httpMethod -eq "POST" -and $decodedPath -eq "/api/test-key") {
            $reader = New-Object System.IO.StreamReader($request.InputStream, $request.ContentEncoding)
            $bodyText = $reader.ReadToEnd()
            $body = $bodyText | ConvertFrom-Json
            $cfg = Get-AppConfig
            $keyToTest = if ($body.apiKey -and -not $body.apiKey.Contains("...") -and -not $body.apiKey.Contains("***")) { $body.apiKey.Trim() } else { $cfg.geminiApiKey }
            $modelToTest = if ($body.model) { $body.model.Trim() } else { if ($cfg.model) { $cfg.model } else { "gemini-3.5-flash-lite" } }

            if ([string]::IsNullOrWhiteSpace($keyToTest)) {
                Send-JsonResponse -Response $response -StatusCode 400 -Object @{ success = $false; error = "ยังไม่มี API Key กรุณากรอก API Key ก่อนทดสอบ" }
                continue
            }

            $testUrl = "https://generativelanguage.googleapis.com/v1beta/models/${modelToTest}:generateContent?key=${keyToTest}"
            $testPayload = @{
                contents = @(
                    @{ parts = @( @{ text = "สวัสดี" } ) }
                )
            } | ConvertTo-Json -Depth 5

            try {
                $testResp = Invoke-RestMethod -Uri $testUrl -Method POST -Body $testPayload -ContentType "application/json; charset=utf-8"
                Send-JsonResponse -Response $response -StatusCode 200 -Object @{
                    success = $true
                    message = "เชื่อมต่อสำเร็จ! Google Gemini ($modelToTest) พร้อมใช้งาน"
                }
            } catch {
                $errMsg = $_.Exception.Message
                try {
                    $stream = $_.Exception.Response.GetResponseStream()
                    $errReader = New-Object System.IO.StreamReader($stream)
                    $errBody = $errReader.ReadToEnd()
                    $errJson = $errBody | ConvertFrom-Json
                    if ($errJson.error.message) {
                        $errMsg = $errJson.error.message
                    }
                } catch {}

                $userFriendly = $errMsg
                if ($errMsg -match "API_KEY_INVALID" -or $errMsg -match "API key not valid") {
                    $userFriendly = "API Key ไม่ถูกต้อง กรุณาคัดลอก Key ให้ครบถ้วนจาก Google AI Studio (ขึ้นต้นด้วย AIzaSy...)"
                } elseif ($errMsg -match "Quota" -or $errMsg -match "RESOURCE_EXHAUSTED") {
                    $userFriendly = "โควตาการใช้งานของ API Key นี้เกินขีดจำกัดชั่วคราว กรุณารอสักครู่หรือเปลี่ยนคีย์"
                } elseif ($errMsg -match "location is not supported") {
                    $userFriendly = "พื้นที่การใช้งานไม่รองรับ (Location not supported) แนะนำให้เปิดใช้งานผ่าน VPN หรือตรวจสอบ Region ใน Google Cloud"
                }

                Send-JsonResponse -Response $response -StatusCode 400 -Object @{
                    success = $false
                    error = $userFriendly
                    rawError = $errMsg
                }
            }
            continue
        }

        # -------------------------------------------------------------
        # API ROUTE: POST /api/analyze-image
        # -------------------------------------------------------------
        if ($httpMethod -eq "POST" -and $decodedPath -eq "/api/analyze-image") {
            $reader = New-Object System.IO.StreamReader($request.InputStream, $request.ContentEncoding)
            $bodyText = $reader.ReadToEnd()
            $body = $bodyText | ConvertFrom-Json

            $cfg = Get-AppConfig
            $apiKey = $cfg.geminiApiKey
            if ([string]::IsNullOrWhiteSpace($apiKey)) {
                Send-JsonResponse -Response $response -StatusCode 400 -Object @{ error = "ยังไม่ได้ระบุ Google Gemini API Key กรุณากดปุ่ม ⚙️ เพื่อตั้งค่าก่อนใช้งาน" }
                continue
            }

            $modelName = if ($cfg.model) { $cfg.model } else { "gemini-3.5-flash-lite" }
            $geminiUrl = "https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${apiKey}"

            $base64Image = $body.image
            if ($base64Image.Contains(",")) {
                $base64Image = $base64Image.Substring($base64Image.IndexOf(",") + 1)
            }
            $mimeType = if ($body.mimeType) { $body.mimeType } else { "image/jpeg" }

            $systemPrompt = @"
คุณคือผู้เชี่ยวชาญ AI ในการอ่านเอกสารบัญชีภาษาไทย ลายมือ สลิปโอนเงินธนาคาร และกระดาษจดสรุปยอดประจำวันของร้านลูกชิ้น (มี 4 สาขา: สาขา 1, สาขา 2, สาขา 3, สาขา 4)

งานของคุณ:
จงวิเคราะห์ภาพที่ได้รับ และสกัดข้อมูลออกมาเป็น JSON ตามโครงสร้างที่กำหนดอย่างเคร่งครัด:
1. document_type: "daily_summary" (ถ้าเป็นกระดาษสรุปยอดประจำวัน) หรือ "expense_receipt" (ใบเสร็จ/บิลซื้อของ) หรือ "transfer_slip" (สลิปโอนเงิน)
2. branch_id: หมายเลขสาขา (1, 2, 3 หรือ 4) หากมีคำว่า สาขา 1 หรือ ส.1 หรือตรวจจากข้อมูลให้ระบุ ถ้าไม่ระบุให้เดาจากบริบทหรือตอบ 1
3. date: วันที่ในรูปแบบ YYYY-MM-DD (ปี พ.ศ. 2569 คือ ค.ศ. 2026 เช่น 691103 คือ 2026-11-03)
4. day_number: เลขวันที่ของเดือน (เช่น วันที่ 2, 3, etc.)
5. total_sales: ยอดขายรวม (บาท) เป็นตัวเลขทศนิยมหรือจำนวนเต็ม (ถ้าเป็นบิลรายจ่ายอย่างเดียวให้ใส่ 0)
6. cash_sales: ยอดขายเงินสด (บาท)
7. transfer_sales: ยอดขายเงินโอน (บาท)
8. total_expenses: ยอดรายจ่ายรวมหน้าร้าน (บาท)
9. expenses: อาร์เรย์ของรายการค่าใช้จ่ายแต่ละรายการ [ { "item": "ชื่อรายการ", "amount": ตัวเลข, "category": "วัตถุดิบ/ค่าแรง/น้ำแข็ง/น้ำมัน/อื่นๆ" } ]
10. rent: ค่าเช่า (ถ้ามีระบุในวันนั้น ถ้าไม่มีให้ใส่ 0)
11. net_profit: กำไรหน้าร้าน (total_sales - total_expenses)
12. remittance: เงินส่งโอนเข้าส่วนกลาง/เงินส่งสด (ถ้ามี)
13. summary_note: สรุปรายละเอียดสั้นๆ เป็นภาษาไทย
14. confidence_notes: ข้อสังเกตเพิ่มเติม หรือจุดที่ตัวเลขอาจไม่ชัดเจนเพื่อให้ผู้ใช้ตรวจทาน

ตอบเฉพาะ JSON ก้อนเดียวเท่านั้น ห้ามมี markdown backticks หรือคำอธิบายอื่น
"@

            $geminiPayload = @{
                contents = @(
                    @{
                        role = "user"
                        parts = @(
                            @{ text = $systemPrompt },
                            @{
                                inline_data = @{
                                    mime_type = $mimeType
                                    data = $base64Image
                                }
                            }
                        )
                    }
                )
                generationConfig = @{
                    temperature = 0.1
                    response_mime_type = "application/json"
                }
            } | ConvertTo-Json -Depth 10

            try {
                $geminiResponse = Invoke-RestMethod -Uri $geminiUrl -Method POST -Body $geminiPayload -ContentType "application/json; charset=utf-8"
                $rawText = $geminiResponse.candidates[0].content.parts[0].text
                
                $cleanJson = $rawText.Trim()
                if ($cleanJson.StartsWith('```json')) {
                    $cleanJson = $cleanJson.Substring(7)
                }
                if ($cleanJson.StartsWith('```')) {
                    $cleanJson = $cleanJson.Substring(3)
                }
                if ($cleanJson.EndsWith('```')) {
                    $cleanJson = $cleanJson.Substring(0, $cleanJson.Length - 3)
                }
                $cleanJson = $cleanJson.Trim()

                $parsedData = $cleanJson | ConvertFrom-Json
                Send-JsonResponse -Response $response -StatusCode 200 -Object @{
                    success = $true
                    data = $parsedData
                    raw = $cleanJson
                }
            } catch {
                $err = $_.Exception.Message
                if ($_.ErrorDetails) { $err = $_.ErrorDetails.Message }
                Send-JsonResponse -Response $response -StatusCode 500 -Object @{
                    success = $false
                    error = "เกิดข้อผิดพลาดในการเรียก Gemini API: $err"
                }
            }
            continue
        }

        # -------------------------------------------------------------
        # API ROUTE: POST /api/save-entry
        # -------------------------------------------------------------
        if ($httpMethod -eq "POST" -and $decodedPath -eq "/api/save-entry") {
            $reader = New-Object System.IO.StreamReader($request.InputStream, $request.ContentEncoding)
            $bodyText = $reader.ReadToEnd()
            $body = $bodyText | ConvertFrom-Json

            $branchId = [int]$body.branch
            if ($branchId -lt 1 -or $branchId -gt 4) { $branchId = 1 }
            $day = [int]$body.day
            $sales = [double]$body.totalSales
            $expenses = [double]$body.expenses
            $note = [string]$body.note
            $base64Image = [string]$body.imageData

            # 1. Save Image to Folder if provided
            $savedImagePath = ""
            if (-not [string]::IsNullOrWhiteSpace($base64Image)) {
                if ($base64Image.Contains(",")) {
                    $base64Image = $base64Image.Substring($base64Image.IndexOf(",") + 1)
                }
                $now = Get-Date
                $mNum = $now.Month
                $monthFolder = if ($thaiMonths.ContainsKey($mNum)) { $thaiMonths[$mNum] } else { "11_พย" }
                $branchDir = Join-Path $scriptDir "สาขา$branchId"
                $targetFolder = Join-Path $branchDir $monthFolder
                if (-not (Test-Path $targetFolder)) {
                    New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
                }

                $yShort = ($now.Year + 543) % 100
                $dayStr = $day.ToString("00")
                $mStr = $mNum.ToString("00")
                $fileName = "69$mStr$dayStr.jpg"
                $fullImgPath = Join-Path $targetFolder $fileName
                
                if (Test-Path $fullImgPath) {
                    $timestamp = (Get-Date).ToString("HHmmss")
                    $fileName = "69$mStr${dayStr}_$timestamp.jpg"
                    $fullImgPath = Join-Path $targetFolder $fileName
                }

                $imageBytes = [System.Convert]::FromBase64String($base64Image)
                [System.IO.File]::WriteAllBytes($fullImgPath, $imageBytes)
                $savedImagePath = "สาขา$branchId/$monthFolder/$fileName"
            }

            # 2. Update รายงานรายวัน_4สาขา.csv
            $dailyCsvPath = Join-Path $scriptDir "รายงานรายวัน_4สาขา.csv"
            if (Test-Path $dailyCsvPath) {
                $lines = [System.IO.File]::ReadAllLines($dailyCsvPath, [System.Text.Encoding]::UTF8)
                $header = $lines[0]
                $updatedLines = New-Object System.Collections.Generic.List[string]
                $updatedLines.Add($header)
                $found = $false

                for ($i = 1; $i -lt $lines.Count; $i++) {
                    $line = $lines[$i].Trim()
                    if ([string]::IsNullOrWhiteSpace($line)) { continue }
                    $parts = $line.Split(',')
                    $d = [int]$parts[0]
                    if ($d -eq $day) {
                        $found = $true
                        $r = @( [double]$parts[1], [double]$parts[2], [double]$parts[3], [double]$parts[4] )
                        $e = @( [double]$parts[6], [double]$parts[7], [double]$parts[8], [double]$parts[9] )
                        $r[$branchId - 1] = $sales
                        $e[$branchId - 1] = $expenses
                        $totR = $r[0] + $r[1] + $r[2] + $r[3]
                        $totE = $e[0] + $e[1] + $e[2] + $e[3]
                        $updatedLines.Add("$day,$($r[0]),$($r[1]),$($r[2]),$($r[3]),$totR,$($e[0]),$($e[1]),$($e[2]),$($e[3]),$totE")
                    } else {
                        $updatedLines.Add($line)
                    }
                }

                if (-not $found) {
                    $r = @(0, 0, 0, 0)
                    $e = @(0, 0, 0, 0)
                    $r[$branchId - 1] = $sales
                    $e[$branchId - 1] = $expenses
                    $totR = $r[0] + $r[1] + $r[2] + $r[3]
                    $totE = $e[0] + $e[1] + $e[2] + $e[3]
                    $updatedLines.Add("$day,$($r[0]),$($r[1]),$($r[2]),$($r[3]),$totR,$($e[0]),$($e[1]),$($e[2]),$($e[3]),$totE")
                }

                [System.IO.File]::WriteAllLines($dailyCsvPath, $updatedLines, $utf8BOM)
            }

            # 3. Maintain data.json for dynamic real-time fetch
            $dataJsonPath = Join-Path $scriptDir "data.json"
            $allData = @{
                lastUpdated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                lastSavedImage = $savedImagePath
            }
            $dailyCsvLines = [System.IO.File]::ReadAllLines($dailyCsvPath, [System.Text.Encoding]::UTF8)
            $parsedDays = @()
            $totR1 = 0; $totR2 = 0; $totR3 = 0; $totR4 = 0
            $totE1 = 0; $totE2 = 0; $totE3 = 0; $totE4 = 0

            for ($i = 1; $i -lt $dailyCsvLines.Count; $i++) {
                $l = $dailyCsvLines[$i].Trim()
                if ([string]::IsNullOrWhiteSpace($l)) { continue }
                $p = $l.Split(',')
                $d = [int]$p[0]
                $r1 = [double]$p[1]; $r2 = [double]$p[2]; $r3 = [double]$p[3]; $r4 = [double]$p[4]
                $e1 = [double]$p[6]; $e2 = [double]$p[7]; $e3 = [double]$p[8]; $e4 = [double]$p[9]
                $parsedDays += @{ day = $d; r1 = $r1; r2 = $r2; r3 = $r3; r4 = $r4; e1 = $e1; e2 = $e2; e3 = $e3; e4 = $e4 }
                $totR1 += $r1; $totR2 += $r2; $totR3 += $r3; $totR4 += $r4
                $totE1 += $e1; $totE2 += $e2; $totE3 += $e3; $totE4 += $e4
            }
            $allData["dailyData"] = $parsedDays
            $allData["totals"] = @{
                branch1 = @{ rev = $totR1; exp = $totE1 }
                branch2 = @{ rev = $totR2; exp = $totE2 }
                branch3 = @{ rev = $totR3; exp = $totE3 }
                branch4 = @{ rev = $totR4; exp = $totE4 }
                all = @{ rev = ($totR1+$totR2+$totR3+$totR4); exp = ($totE1+$totE2+$totE3+$totE4) }
            }

            $jsonOut = $allData | ConvertTo-Json -Depth 5
            [System.IO.File]::WriteAllText($dataJsonPath, $jsonOut, [System.Text.Encoding]::UTF8)

            Send-JsonResponse -Response $response -StatusCode 200 -Object @{
                success = $true
                message = "บันทึกข้อมูลเรียบร้อยแล้ว!"
                savedImage = $savedImagePath
                data = $allData
            }
            continue
        }

        # -------------------------------------------------------------
        # API ROUTE: GET /api/data
        # -------------------------------------------------------------
        if ($httpMethod -eq "GET" -and $decodedPath -eq "/api/data") {
            $dataJsonPath = Join-Path $scriptDir "data.json"
            if (Test-Path $dataJsonPath) {
                $raw = [System.IO.File]::ReadAllText($dataJsonPath, [System.Text.Encoding]::UTF8)
                $dataObj = $raw | ConvertFrom-Json
                Send-JsonResponse -Response $response -StatusCode 200 -Object $dataObj
            } else {
                Send-JsonResponse -Response $response -StatusCode 200 -Object @{ dailyData = @() }
            }
            continue
        }

        # -------------------------------------------------------------
        # STATIC FILE SERVING
        # -------------------------------------------------------------
        $localRelPath = $decodedPath.TrimStart('/')
        if ([string]::IsNullOrWhiteSpace($localRelPath)) {
            $localRelPath = "dashboard.html"
        }
        $localFullPath = Join-Path $scriptDir $localRelPath

        if (Test-Path $localFullPath -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($localFullPath).ToLower()
            $mime = "application/octet-stream"
            switch ($ext) {
                ".html" { $mime = "text/html; charset=utf-8" }
                ".htm"  { $mime = "text/html; charset=utf-8" }
                ".css"  { $mime = "text/css; charset=utf-8" }
                ".js"   { $mime = "application/javascript; charset=utf-8" }
                ".json" { $mime = "application/json; charset=utf-8" }
                ".csv"  { $mime = "text/csv; charset=utf-8" }
                ".jpg"  { $mime = "image/jpeg" }
                ".jpeg" { $mime = "image/jpeg" }
                ".png"  { $mime = "image/png" }
                ".webp" { $mime = "image/webp" }
                ".gif"  { $mime = "image/gif" }
                ".svg"  { $mime = "image/svg+xml" }
                ".ico"  { $mime = "image/x-icon" }
            }
            $bytes = [System.IO.File]::ReadAllBytes($localFullPath)
            Send-Response -Response $response -StatusCode 200 -ContentType $mime -Data $bytes
        } else {
            $errBytes = $utf8NoBOM.GetBytes("404 Not Found: $decodedPath")
            Send-Response -Response $response -StatusCode 404 -ContentType "text/plain; charset=utf-8" -Data $errBytes
        }

    } catch {
        Write-Host "Error processing request: $_" -ForegroundColor Red
    }
}