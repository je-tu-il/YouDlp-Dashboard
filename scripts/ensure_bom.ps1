$files = @("main.ahk", "main_lite.ahk")
foreach ($f in $files) {
    $bytes = [System.IO.File]::ReadAllBytes($f)
    if ($bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
        $bom = [byte[]](0xEF, 0xBB, 0xBF)
        $newBytes = $bom + $bytes
        [System.IO.File]::WriteAllBytes($f, $newBytes)
        Write-Output "Added BOM to $f"
    } else {
        Write-Output "BOM already present in $f"
    }
}
