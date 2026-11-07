# sync_data.ps1 - Synchronizes all CSV files and data.json from database.json
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$workDir = (Get-Location).Path
$dbPath = Join-Path $workDir "database.json"

if (-not (Test-Path $dbPath)) {
    Write-Error "database.json not found in $workDir"
    exit 1
}

$db = Get-Content $dbPath -Raw -Encoding UTF8 | ConvertFrom-Json
Write-Host "Loaded database.json successfully (Version: $($db.metadata.version), Latest Day: $($db.metadata.latestDay))"

# 1. Generate รายงานรายวัน_4สาขา.csv
$dailyCsvLines = @("วันที่,ยอดขาย_สาขา1,ยอดขาย_สาขา2,ยอดขาย_สาขา3,ยอดขาย_สาขา4,ยอดขาย_รวม4สาขา,รายจ่าย_สาขา1,รายจ่าย_สาขา2,รายจ่าย_สาขา3,รายจ่าย_สาขา4,รายจ่าย_รวม4สาขา")
foreach ($d in $db.currentMonthDaily) {
    $r1 = [int]$d.branches.branch1.revenue
    $r2 = [int]$d.branches.branch2.revenue
    $r3 = [int]$d.branches.branch3.revenue
    $r4 = [int]$d.branches.branch4.revenue
    $rTot = $r1 + $r2 + $r3 + $r4

    $e1 = [int]$d.branches.branch1.totalExpense
    $e2 = [int]$d.branches.branch2.totalExpense
    $e3 = [int]$d.branches.branch3.totalExpense
    $e4 = [int]$d.branches.branch4.totalExpense
    $eTot = $e1 + $e2 + $e3 + $e4

    $dailyCsvLines += "$($d.day),$r1,$r2,$r3,$r4,$rTot,$e1,$e2,$e3,$e4,$eTot"
}
$dailyCsvPath = Join-Path $workDir "รายงานรายวัน_4สาขา.csv"
[System.IO.File]::WriteAllLines($dailyCsvPath, $dailyCsvLines, [System.Text.Encoding]::UTF8)
Write-Host "Updated: รายงานรายวัน_4สาขา.csv" -ForegroundColor Green

# Calculate Cumulative Totals for Current Month
$b1Rev = 0; $b1OpExp = 0; $b1Rent = [double]$db.branchConfig.branch1.fixedRent; $b1Sent = 0
$b2Rev = 0; $b2OpExp = 0; $b2Rent = [double]$db.branchConfig.branch2.fixedRent; $b2Sent = 0
$b3Rev = 0; $b3OpExp = 0; $b3Rent = [double]$db.branchConfig.branch3.fixedRent; $b3Sent = 0
$b4Rev = 0; $b4OpExp = 0; $b4Rent = [double]$db.branchConfig.branch4.fixedRent; $b4Sent = 0

foreach ($d in $db.currentMonthDaily) {
    $b1Rev += $d.branches.branch1.revenue; $b1OpExp += $d.branches.branch1.opExpense; $b1Sent += $d.branches.branch1.sent
    $b2Rev += $d.branches.branch2.revenue; $b2OpExp += $d.branches.branch2.opExpense; $b2Sent += $d.branches.branch2.sent
    $b3Rev += $d.branches.branch3.revenue; $b3OpExp += $d.branches.branch3.opExpense; $b3Sent += $d.branches.branch3.sent
    $b4Rev += $d.branches.branch4.revenue; $b4OpExp += $d.branches.branch4.opExpense; $b4Sent += $d.branches.branch4.sent
}

$totRev = $b1Rev + $b2Rev + $b3Rev + $b4Rev
$totOpExp = $b1OpExp + $b2OpExp + $b3OpExp + $b4OpExp
$totRent = $b1Rent + $b2Rent + $b3Rent + $b4Rent
$totExp = $totOpExp + $totRent
$totSent = $b1Sent + $b2Sent + $b3Sent + $b4Sent
$days = $db.currentMonthDaily.Count

# 2. Generate สรุปภาพรวม_4สาขา.csv
$b1TotExp = $b1OpExp + $b1Rent; $b1OpProfit = $b1Rev - $b1OpExp; $b1Net = $b1Rev - $b1TotExp; $b1Margin = [math]::Round(($b1Net / $b1Rev) * 100, 2)
$b2TotExp = $b2OpExp + $b2Rent; $b2OpProfit = $b2Rev - $b2OpExp; $b2Net = $b2Rev - $b2TotExp; $b2Margin = [math]::Round(($b2Net / $b2Rev) * 100, 2)
$b3TotExp = $b3OpExp + $b3Rent; $b3OpProfit = $b3Rev - $b3OpExp; $b3Net = $b3Rev - $b3TotExp; $b3Margin = [math]::Round(($b3Net / $b3Rev) * 100, 2)
$b4TotExp = $b4OpExp + $b4Rent; $b4OpProfit = $b4Rev - $b4OpExp; $b4Net = $b4Rev - $b4TotExp; $b4Margin = [math]::Round(($b4Net / $b4Rev) * 100, 2)
$totOpProfit = $totRev - $totOpExp; $totNet = $totRev - $totExp; $totMargin = [math]::Round(($totNet / $totRev) * 100, 2)

$summaryLines = @(
    "สาขา,ยอดขายรวม,สัดส่วนยอดขาย,รายจ่ายดำเนินงาน,ค่าเช่าต่อเดือน,รายจ่ายรวม,กำไรดำเนินงาน,กำไรสุทธิ (Cash Basis),อัตรากำไรสุทธิ,หมายเหตุ",
    "สาขา 1,$b1Rev,$([math]::Round(($b1Rev/$totRev)*100, 2))%,$([math]::Round($b1OpExp,2)),$([math]::Round($b1Rent,2)),$([math]::Round($b1TotExp,2)),$([math]::Round($b1OpProfit,2)),$([math]::Round($b1Net,2)),$b1Margin%,สะสม $days วัน ยอดขาย $b1Rev จ่ายดำเนินงาน $([math]::Round($b1OpExp,0)) เช่า $([math]::Round($b1Rent,0)) ส่งโอนรวม $b1Sent",
    "สาขา 2,$b2Rev,$([math]::Round(($b2Rev/$totRev)*100, 2))%,$([math]::Round($b2OpExp,2)),$([math]::Round($b2Rent,2)),$([math]::Round($b2TotExp,2)),$([math]::Round($b2OpProfit,2)),$([math]::Round($b2Net,2)),$b2Margin%,สะสม $days วัน ยอดขาย $b2Rev จ่ายดำเนินงาน $([math]::Round($b2OpExp,0)) เช่า $([math]::Round($b2Rent,2)) ส่งโอนรวม $b2Sent",
    "สาขา 3,$b3Rev,$([math]::Round(($b3Rev/$totRev)*100, 2))%,$([math]::Round($b3OpExp,2)),$([math]::Round($b3Rent,2)),$([math]::Round($b3TotExp,2)),$([math]::Round($b3OpProfit,2)),$([math]::Round($b3Net,2)),$b3Margin%,สะสม $days วัน ยอดขาย $b3Rev จ่ายดำเนินงาน $([math]::Round($b3OpExp,0)) เช่า $([math]::Round($b3Rent,0)) ส่งโอนรวม $b3Sent",
    "สาขา 4,$b4Rev,$([math]::Round(($b4Rev/$totRev)*100, 2))%,$([math]::Round($b4OpExp,2)),$([math]::Round($b4Rent,2)),$([math]::Round($b4TotExp,2)),$([math]::Round($b4OpProfit,2)),$([math]::Round($b4Net,2)),$b4Margin%,สะสม $days วัน ยอดขาย $b4Rev จ่ายดำเนินงาน $([math]::Round($b4OpExp,0)) เช่า $([math]::Round($b4Rent,2)) ส่งโอนรวม $b4Sent",
    "รวมทั้ง 4 สาขา,$totRev,100.00%,$([math]::Round($totOpExp,2)),$([math]::Round($totRent,2)),$([math]::Round($totExp,2)),$([math]::Round($totOpProfit,2)),$([math]::Round($totNet,2)),$totMargin%,เกณฑ์เงินสด รวมค่าเช่าสดครบ 4 สาขาทั้งเดือน $([math]::Round($totRent,2)) บ. รายจ่ายรวม $([math]::Round($totExp,2)) บ. ยอดส่งโอนรวม $totSent บ."
)
$summaryCsvPath = Join-Path $workDir "สรุปภาพรวม_4สาขา.csv"
[System.IO.File]::WriteAllLines($summaryCsvPath, $summaryLines, [System.Text.Encoding]::UTF8)
Write-Host "Updated: สรุปภาพรวม_4สาขา.csv" -ForegroundColor Green

# 3. Calculate 11-Month Annual Totals
$annB1Rev = 0; $annB1OpExp = 0; $annB1Rent = 0; $annB1TotExp = 0; $annB1Net = 0
$annB2Rev = 0; $annB2OpExp = 0; $annB2Rent = 0; $annB2TotExp = 0; $annB2Net = 0
$annB3Rev = 0; $annB3OpExp = 0; $annB3Rent = 0; $annB3TotExp = 0; $annB3Net = 0
$annB4Rev = 0; $annB4OpExp = 0; $annB4Rent = 0; $annB4TotExp = 0; $annB4Net = 0

foreach ($m in $db.history.branch1) {
    $annB1Rev += $m.rev; $annB1OpExp += $m.opExp; $annB1Rent += $m.rent; $annB1TotExp += $m.totalExp; $annB1Net += $m.net
}
$annB1Rev += $b1Rev; $annB1OpExp += $b1OpExp; $annB1Rent += $b1Rent; $annB1TotExp += $b1TotExp; $annB1Net += $b1Net

foreach ($m in $db.history.branch2) {
    $annB2Rev += $m.rev; $annB2OpExp += $m.opExp; $annB2Rent += $m.rentPaid; $annB2TotExp += $m.totalExp; $annB2Net += $m.net
}
$annB2Rev += $b2Rev; $annB2OpExp += $b2OpExp; $annB2Rent += $b2Rent; $annB2TotExp += $b2TotExp; $annB2Net += $b2Net

foreach ($m in $db.history.branch3) {
    $annB3Rev += $m.rev; $annB3OpExp += $m.opExp; $annB3Rent += $m.rent; $annB3TotExp += $m.totalExp; $annB3Net += $m.net
}
$annB3Rev += $b3Rev; $annB3OpExp += $b3OpExp; $annB3Rent += $b3Rent; $annB3TotExp += $b3TotExp; $annB3Net += $b3Net

foreach ($m in $db.history.branch4) {
    $annB4Rev += $m.rev; $annB4OpExp += $m.opExp; $annB4Rent += $m.rentPaid; $annB4TotExp += $m.totalExp; $annB4Net += $m.net
}
$annB4Rev += $b4Rev; $annB4OpExp += $b4OpExp; $annB4Rent += $b4Rent; $annB4TotExp += $b4TotExp; $annB4Net += $b4Net

$annTotRev = $annB1Rev + $annB2Rev + $annB3Rev + $annB4Rev
$annTotOpExp = $annB1OpExp + $annB2OpExp + $annB3OpExp + $annB4OpExp
$annTotRent = $annB1Rent + $annB2Rent + $annB3Rent + $annB4Rent
$annTotExp = $annB1TotExp + $annB2TotExp + $annB3TotExp + $annB4TotExp
$annTotNet = $annB1Net + $annB2Net + $annB3Net + $annB4Net

# 4. Generate สรุปภาพรวมปี_2569.csv
$annualCsvLines = @(
    "ตารางที่ 1: สรุปเปรียบเทียบผลประกอบการ 4 สาขา ประจำปี 2569 (มกราคม - พฤศจิกายน 2569 ข้อมูลถึง $days พ.ย.)",
    "สาขา,ช่วงเวลาที่มีข้อมูล,รายรับรวม (บาท),สัดส่วนรายรับ,รายจ่ายดำเนินงาน (บาท),ค่าเช่าบันทึก (บาท),รายจ่ายรวม (บาท),กำไร/ขาดทุนสุทธิ (บาท),อัตรากำไร (Margin),บทบาทและสถานะทางธุรกิจ",
    "สาขา 1,11 เดือน (ม.ค.-$days พ.ย.),$annB1Rev,$([math]::Round(($annB1Rev/$annTotRev)*100,2))%,$([math]::Round($annB1OpExp,0)),$([math]::Round($annB1Rent,0)),$([math]::Round($annB1TotExp,0)),$([math]::Round($annB1Net,0)),$([math]::Round(($annB1Net/$annB1Rev)*100,2))%,Cash Cow อันดับ 1 (กำไรสุทธิสูงสุดและยอดขายสูงสุดในกลุ่ม ทะลุ $([math]::Round($annB1Rev/10000,2)) แสน ว.$days ขาย $([math]::Round($db.currentMonthDaily[-1].branches.branch1.revenue,0)) บ. สต็อกลูกชิ้น 2,880 บ. 🥇)",
    "สาขา 2,9 เดือน (มี.ค.-$days พ.ย.),$annB2Rev,$([math]::Round(($annB2Rev/$annTotRev)*100,2))%,$([math]::Round($annB2OpExp,0)),$([math]::Round($annB2Rent,2)),$([math]::Round($annB2TotExp,2)),$([math]::Round($annB2Net,2)),$([math]::Round(($annB2Net/$annB2Rev)*100,2))%,เปิด มี.ค. 69 ยอดสะสมแตะ $([math]::Round($annB2Rev/10000,3)) แสนบาท ว.$days ขาย $([math]::Round($db.currentMonthDaily[-1].branches.branch2.revenue,0)) บ. สต็อกไก่จ๊อ/หมูปิ้ง 🎯",
    "สาขา 3,11 เดือน (ม.ค.-$days พ.ย.),$annB3Rev,$([math]::Round(($annB3Rev/$annTotRev)*100,2))%,$([math]::Round($annB3OpExp,0)),$([math]::Round($annB3Rent,0)),$([math]::Round($annB3TotExp,0)),$([math]::Round($annB3Net,0)),$([math]::Round(($annB3Net/$annB3Rev)*100,2))%,ยอดขายสม่ำเสมออันดับ 2 ทะลุ $([math]::Round($annB3Rev/10000,2)) แสนบาท ว.$days แชมป์ยอดขาย $([math]::Round($db.currentMonthDaily[-1].branches.branch3.revenue,0)) บ. สต็อกไข่เต่า/มันกล้วย 🏆 🥈",
    "สาขา 4,9 เดือน (มี.ค.-$days พ.ย.),$annB4Rev,$([math]::Round(($annB4Rev/$annTotRev)*100,2))%,$([math]::Round($annB4OpExp,0)),$([math]::Round($annB4Rent,0)),$([math]::Round($annB4TotExp,0)),$([math]::Round($annB4Net,0)),$([math]::Round(($annB4Net/$annB4Rev)*100,2))%,เติบโตเร็ว ทะลุ $([math]::Round($annB4Rev/10000,3)) แสนบาท ว.$days ยอดขายพุ่ง $([math]::Round($db.currentMonthDaily[-1].branches.branch4.revenue,0)) บ. สต็อกกล้วย/ไก่จ๊อ 🚀",
    "รวมทั้งกิจการ,ม.ค. - $days พ.ย. 2569,$annTotRev,100.00%,$([math]::Round($annTotOpExp,0)),$([math]::Round($annTotRent,2)),$([math]::Round($annTotExp,2)),$([math]::Round($annTotNet,2)),$([math]::Round(($annTotNet/$annTotRev)*100,2))%,ยอดขายสะสมทั้งปีทะลุ $([math]::Round($annTotRev/1000000,3)) ล้านบาท ($([string]::Format('{0:N0}', $annTotRev)) บ.) 🎉 (เกณฑ์เงินสด Cash Basis รวมจ่ายค่าเช่าสดล่วงหน้าทั้งเดือน พ.ย. ครบ $([string]::Format('{0:N2}', $totRent)) บ. รายจ่ายรวม $([string]::Format('{0:N0}', $annTotExp)) บ.)",
    "",
    "ตารางที่ 2: สรุปผลประกอบการรายเดือนทั้งกิจการ ปี 2569 (มกราคม - พฤศจิกายน 2569 ข้อมูลถึง $days พ.ย.)",
    "เดือน,ปี,สาขา 1 (บาท),สาขา 2 (บาท),สาขา 3 (บาท),สาขา 4 (บาท),รายรับรวม (บาท),รายจ่ายรวม (บาท),กำไร/ขาดทุนสุทธิ (บาท),อัตรากำไร (Margin),หมายเหตุสำคัญ"
)

foreach ($a in $db.history.annual) {
    $annualCsvLines += "$($a.fullMonth.Split(' ')[0]),$($a.year),$($a.b1Rev),$($a.b2Rev),$($a.b3Rev),$($a.b4Rev),$($a.rev),$($a.totalExp),$($a.net),$($a.margin)%,$($a.note)"
}
# Current Month row
$novMargin = [math]::Round(($totNet / $totRev) * 100, 2)
$annualCsvLines += "พฤศจิกายน ($days วัน),2569,$b1Rev,$b2Rev,$b3Rev,$b4Rev,$totRev,$([math]::Round($totExp,0)),$([math]::Round($totNet,0)),$novMargin%,`"สะสม $days วัน (1-$days พ.ย. 69) ยอดขาย $([string]::Format('{0:N0}',$totRev)) บ. จ่ายค่าเช่าสดครบ 4 สาขา $([string]::Format('{0:N2}',$totRent)) บ. รายจ่ายรวมเกณฑ์เงินสด $([string]::Format('{0:N0}',$totExp)) บ. ว.$days เสาร์ยอดขายพุ่ง ฿5,231 นำโดย ส.3 (฿1,889) และ ส.4 (฿1,580) สต็อกของพร้อมขายสัปดาห์ใหม่`""
# Cumulative row
$annMargin = [math]::Round(($annTotNet / $annTotRev) * 100, 2)
$annualCsvLines += "รวมสะสม 11 เดือน,-,$annB1Rev,$annB2Rev,$annB3Rev,$annB4Rev,$annTotRev,$([math]::Round($annTotExp,0)),$([math]::Round($annTotNet,0)),$annMargin%,`"ยอดขายสะสมทะลุ $([math]::Round($annTotRev/1000000,3)) ล้านบาท ($([string]::Format('{0:N0}', $annTotRev)) บ.) 🎉 รายจ่ายรวม $([string]::Format('{0:N0}', $annTotExp)) บ. (รวมค่าเช่าจ่ายสดล่วงหน้าทั้งเดือน พ.ย. ครบ 100%)`""

$annualCsvPath = Join-Path $workDir "สรุปภาพรวมปี_2569.csv"
[System.IO.File]::WriteAllLines($annualCsvPath, $annualCsvLines, [System.Text.Encoding]::UTF8)
Write-Host "Updated: สรุปภาพรวมปี_2569.csv" -ForegroundColor Green

# 5. Generate สรุปประวัติย้อนหลัง_สาขา1.csv
$b1Lines = @("เดือน,ปี,เป้าหมายยอดขาย (บาท),รายรับจริง (บาท),รายจ่ายดำเนินงาน (บาท),ค่าเช่าบันทึก (บาท),รายจ่ายรวม (บาท),กำไร/ขาดทุนสุทธิ (บาท),อัตรากำไร (Margin),หมายเหตุและสถานะ")
foreach ($m in $db.history.branch1) {
    $b1Lines += "$($m.fullMonth.Split(' ')[0]),2569,$($m.target),$($m.rev),$($m.opExp),$($m.rent),$($m.totalExp),$($m.net),$($m.margin)%,$($m.note)"
}
$b1NovMargin = [math]::Round(($b1Net / $b1Rev) * 100, 2)
$b1Lines += "พฤศจิกายน ($days วัน),2569,$([int]$db.branchConfig.branch1.monthlyTarget),$b1Rev,$([math]::Round($b1OpExp,0)),$([math]::Round($b1Rent,0)),$([math]::Round($b1TotExp,0)),$([math]::Round($b1Net,0)),$b1NovMargin%,`"สะสม $days วัน (1-$days พ.ย. 69) ยอดขาย $([string]::Format('{0:N0}',$b1Rev)) บ. (ว.$days ขาย $([string]::Format('{0:N0}',$db.currentMonthDaily[-1].branches.branch1.revenue)) บ. สต็อกลูกชิ้น ฿2,880 หมูปิ้ง ฿600 น้ำจิ้ม ฿300) จ่ายดำเนินงาน $([string]::Format('{0:N0}',$b1OpExp)) บ. ค่าเช่า $([string]::Format('{0:N0}',$b1Rent)) บ. รวมจ่าย $([string]::Format('{0:N0}',$b1TotExp)) บ. 🥇`""
$b1AnnMargin = [math]::Round(($annB1Net / $annB1Rev) * 100, 2)
$b1Lines += "รวมสะสม 11 เดือน,-,-,$annB1Rev,$([math]::Round($annB1OpExp,0)),$([math]::Round($annB1Rent,0)),$([math]::Round($annB1TotExp,0)),$([math]::Round($annB1Net,0)),$b1AnnMargin%,`"ยอดขายและกำไรสุทธิสะสมอันดับ 1 ของทุกสาขา (ยอดขายแตะ $([math]::Round($annB1Rev/10000,2)) แสน กำไรสะสมแตะ $([math]::Round($annB1Net/10000,2)) หมื่นบาท)`""
[System.IO.File]::WriteAllLines((Join-Path $workDir "สรุปประวัติย้อนหลัง_สาขา1.csv"), $b1Lines, [System.Text.Encoding]::UTF8)
Write-Host "Updated: สรุปประวัติย้อนหลัง_สาขา1.csv" -ForegroundColor Green

# 6. Generate สรุปประวัติย้อนหลัง_สาขา2.csv
$b2Lines = @("เดือน,เป้าหมายยอดขาย (บาท),รายรับจริง (บาท),รายจ่ายดำเนินงาน (บาท),ค่าเช่าจ่ายจริง (บาท),ค่าเช่าเฉลี่ยต่อเดือน (บาท),กำไร/ขาดทุนสุทธิ (บาท),อัตรากำไร (%),หมายเหตุ")
foreach ($m in $db.history.branch2) {
    $b2Lines += "$($m.fullMonth),$($m.target),$($m.rev),$($m.opExp),$($m.rentPaid),$($m.rentAmort),$($m.net),$($m.margin)%,$($m.note)"
}
$b2NovMargin = [math]::Round(($b2Net / $b2Rev) * 100, 2)
$b2Lines += "พฤศจิกายน ($days วัน),$([int]$db.branchConfig.branch2.monthlyTarget),$b2Rev,$([math]::Round($b2OpExp,0)),$([math]::Round($b2Rent,0)),$([math]::Round($b2Rent,2)),$([math]::Round($b2Net,0)),$b2NovMargin%,`"สะสม $days วัน (1-$days พ.ย. 69) ยอดขาย $([string]::Format('{0:N0}',$b2Rev)) บ. (ว.$days ขาย $([string]::Format('{0:N0}',$db.currentMonthDaily[-1].branches.branch2.revenue)) บ. สต็อกไก่จ๊อ ฿707 หมูปิ้ง ฿550) จ่ายดำเนินงาน $([string]::Format('{0:N0}',$b2OpExp)) บ. ค่าเช่า $([string]::Format('{0:N0}',$b2Rent)) บ. รวมจ่าย $([string]::Format('{0:N0}',$b2TotExp)) บ.`""
$b2AnnMargin = [math]::Round(($annB2Net / $annB2Rev) * 100, 2)
$b2Lines += "รวม 9 เดือน (มี.ค. - $days พ.ย. 69),-,$annB2Rev,$([math]::Round($annB2OpExp,0)),$([math]::Round($annB2Rent,2)),$([math]::Round($annB2Rent,2)),$([math]::Round($annB2Net,2)),$b2AnnMargin%,`"ยอดขายสะสมแตะ $([math]::Round($annB2Rev/10000,3)) แสนบาท รายจ่ายรวม $([string]::Format('{0:N2}',$annB2TotExp)) บ.`""
[System.IO.File]::WriteAllLines((Join-Path $workDir "สรุปประวัติย้อนหลัง_สาขา2.csv"), $b2Lines, [System.Text.Encoding]::UTF8)
Write-Host "Updated: สรุปประวัติย้อนหลัง_สาขา2.csv" -ForegroundColor Green

# 7. Generate สรุปประวัติย้อนหลัง_สาขา3.csv
$b3Lines = @("เดือน,ปี,เป้าหมายยอดขาย (บาท),รายรับจริง (บาท),รายจ่ายรวม (บาท),ค่าเช่าบันทึก (บาท),กำไร/ขาดทุนสุทธิ (บาท),อัตรากำไร (Margin),หมายเหตุและสถานะ")
foreach ($m in $db.history.branch3) {
    $b3Lines += "$($m.fullMonth.Split(' ')[0]),2569,$($m.target),$($m.rev),$($m.totalExp),$($m.rent),$($m.net),$($m.margin)%,$($m.note)"
}
$b3NovMargin = [math]::Round(($b3Net / $b3Rev) * 100, 2)
$b3Lines += "พฤศจิกายน ($days วัน),2569,$([int]$db.branchConfig.branch3.monthlyTarget),$b3Rev,$([math]::Round($b3TotExp,0)),$([math]::Round($b3Rent,0)),$([math]::Round($b3Net,0)),$b3NovMargin%,`"สะสม $days วัน (1-$days พ.ย. 69) ยอดขาย $([string]::Format('{0:N0}',$b3Rev)) บ. (ว.$days ยอดขายสูงสุด $([string]::Format('{0:N0}',$db.currentMonthDaily[-1].branches.branch3.revenue)) บ. สต็อกไข่เต่า/มันกล้วย) จ่ายดำเนินงาน $([string]::Format('{0:N0}',$b3OpExp)) บ. ค่าเช่าจ่ายสด $([string]::Format('{0:N0}',$b3Rent)) บ. รวมจ่าย $([string]::Format('{0:N0}',$b3TotExp)) บ. ส่งเงินรวมสะสม $([string]::Format('{0:N0}',$b3Sent)) บ. 🏆`""
$b3AnnMargin = [math]::Round(($annB3Net / $annB3Rev) * 100, 2)
$b3Lines += "รวมสะสม 11 เดือน,-,-,$annB3Rev,$([math]::Round($annB3TotExp,0)),$([math]::Round($annB3Rent,0)),$([math]::Round($annB3Net,0)),$b3AnnMargin%,`"ยอดขายสม่ำเสมออันดับ 2 ทะลุ $([math]::Round($annB3Rev/10000,2)) แสนบาท ($([string]::Format('{0:N0}',$annB3Rev)) บ.) รายจ่ายรวม $([string]::Format('{0:N0}',$annB3TotExp)) บ.`""
[System.IO.File]::WriteAllLines((Join-Path $workDir "สรุปประวัติย้อนหลัง_สาขา3.csv"), $b3Lines, [System.Text.Encoding]::UTF8)
Write-Host "Updated: สรุปประวัติย้อนหลัง_สาขา3.csv" -ForegroundColor Green

# 8. Generate สรุปประวัติย้อนหลัง_สาขา4.csv
$b4Lines = @("เดือน,เป้าหมายยอดขาย (บาท),รายรับจริง (บาท),รายจ่ายดำเนินงาน (บาท),ค่าเช่าจ่ายจริง (บาท),ค่าเช่าเฉลี่ยต่อเดือน (บาท),กำไร/ขาดทุนสุทธิ (บาท),อัตรากำไร (%),หมายเหตุ")
foreach ($m in $db.history.branch4) {
    $b4Lines += "$($m.fullMonth),$($m.target),$($m.rev),$($m.opExp),$($m.rentPaid),$($m.rentAmort),$($m.net),$($m.margin)%,$($m.note)"
}
$b4NovMargin = [math]::Round(($b4Net / $b4Rev) * 100, 2)
$b4Lines += "พฤศจิกายน ($days วัน),$([int]$db.branchConfig.branch4.monthlyTarget),$b4Rev,$([math]::Round($b4OpExp,0)),$([math]::Round($b4Rent,0)),$([math]::Round($b4Rent,2)),$([math]::Round($b4Net,0)),$b4NovMargin%,`"สะสม $days วัน (1-$days พ.ย. 69) ยอดขาย $([string]::Format('{0:N0}',$b4Rev)) บ. (ว.$days ยอดขายพุ่ง $([string]::Format('{0:N0}',$db.currentMonthDaily[-1].branches.branch4.revenue)) บ. สต็อกกล้วย/ไก่จ๊อ/ไข่เต่า) จ่ายดำเนินงาน $([string]::Format('{0:N0}',$b4OpExp)) บ. ค่าเช่า $([string]::Format('{0:N0}',$b4Rent)) บ. รวมจ่าย $([string]::Format('{0:N0}',$b4TotExp)) บ.`""
$b4AnnMargin = [math]::Round(($annB4Net / $annB4Rev) * 100, 2)
$b4Lines += "รวม 9 เดือน (มี.ค. - $days พ.ย. 69),-,$annB4Rev,$([math]::Round($annB4OpExp,0)),$([math]::Round($annB4Rent,2)),$([math]::Round($annB4Rent,2)),$([math]::Round($annB4Net,2)),$b4AnnMargin%,`"ยอดขายสะสมแตะ $([math]::Round($annB4Rev/10000,3)) แสนบาท เติบโตต่อเนื่อง ทะลุ $([math]::Round($annB4Rev/10000,3)) แสนบาท`""
[System.IO.File]::WriteAllLines((Join-Path $workDir "สรุปประวัติย้อนหลัง_สาขา4.csv"), $b4Lines, [System.Text.Encoding]::UTF8)
Write-Host "Updated: สรุปประวัติย้อนหลัง_สาขา4.csv" -ForegroundColor Green

# 9. Update data.json for compatibility
$dailyDataArr = @()
foreach ($d in $db.currentMonthDaily) {
    $dailyDataArr += @{
        day = $d.day
        r1 = $d.branches.branch1.revenue
        r2 = $d.branches.branch2.revenue
        r3 = $d.branches.branch3.revenue
        r4 = $d.branches.branch4.revenue
        e1 = [int]$d.branches.branch1.totalExpense
        e2 = [int]$d.branches.branch2.totalExpense
        e3 = [int]$d.branches.branch3.totalExpense
        e4 = [int]$d.branches.branch4.totalExpense
    }
}

$oldDataJsonPath = Join-Path $workDir "data.json"
$lastSavedImage = "สาขา4/11_พค/S__3784714.jpg"
if (Test-Path $oldDataJsonPath) {
    try {
        $oldObj = Get-Content $oldDataJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($oldObj.lastSavedImage) { $lastSavedImage = $oldObj.lastSavedImage }
    } catch {}
}

$compatData = @{
    lastSavedImage = $lastSavedImage
    totals = @{
        branch1 = @{ exp = [int]$b1TotExp; rev = [int]$b1Rev }
        branch2 = @{ exp = [int]$b2TotExp; rev = [int]$b2Rev }
        branch3 = @{ exp = [int]$b3TotExp; rev = [int]$b3Rev }
        branch4 = @{ exp = [int]$b4TotExp; rev = [int]$b4Rev }
        all = @{ exp = [int]$totExp; rev = [int]$totRev }
    }
    lastUpdated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    dailyData = $dailyDataArr
}
$compatJson = $compatData | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($oldDataJsonPath, $compatJson, [System.Text.Encoding]::UTF8)
Write-Host "Updated: data.json (Compatibility mode)" -ForegroundColor Green

Write-Host "`nAll 7 CSV files and data.json synchronized successfully from database.json!" -ForegroundColor Cyan
