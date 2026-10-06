# Local adb runtime helper. No login credentials, coordinates, or fixture data stored.
$Round3Adb='C:/Users/kuoja/AppData/Local/Android/Sdk/platform-tools/adb.exe'
function Get-Round3Ui([string]$Serial) {
    $dump=(& $Round3Adb -s $Serial shell uiautomator dump /sdcard/r3-window.xml) -join ''
    if($LASTEXITCODE -ne 0 -or $dump -notmatch 'dumped to') {
        throw 'Fresh UI snapshot failed; refusing to use a stale snapshot.'
    }
    $xml=(& $Round3Adb -s $Serial shell cat /sdcard/r3-window.xml) -join ''
    if($LASTEXITCODE -ne 0) {throw 'UI snapshot read failed.'}
    [xml]$tree=$xml
    return $tree
}
function Invoke-Round3Tap([string]$Serial,[string]$Description) {
    $node=$null
    for($attempt=0;$attempt -lt 4;$attempt++) {
        $tree=Get-Round3Ui $Serial
        $node=$tree.SelectNodes('//node') | Where-Object {$_.'content-desc' -eq $Description -or $_.text -eq $Description} | Select-Object -First 1
        if($node) {break}
    }
    if(!$node -or $node.bounds -notmatch '^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$') {throw "Visible target unavailable: $Description"}
    $x=[int](([int]$Matches[1]+[int]$Matches[3])/2)
    $y=[int](([int]$Matches[2]+[int]$Matches[4])/2)
    $null=& $Round3Adb -s $Serial shell input tap $x $y
    $null=Get-Round3Ui $Serial
}
function Show-Round3Ui([string]$Serial) {
    (Get-Round3Ui $Serial).SelectNodes('//node') | Where-Object {$_.'content-desc'} | Select-Object content-desc,bounds
}
