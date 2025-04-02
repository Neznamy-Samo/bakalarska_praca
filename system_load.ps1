$ProcessName = "Wireshark"
$SampleInterval = 1    
$Duration = 60      
$OutputPath = ".\${ProcessName}_Usage_$timestamp.csv"

$ProcessorCount = (Get-WmiObject Win32_ComputerSystem).NumberOfLogicalProcessors
$Samples = @()

Write-Host "Monitoring CPU and RAM usage for process '$ProcessName' over $Duration seconds..."

for ($i = 0; $i -lt $Duration; $i += $SampleInterval) {
    $process = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue

    $cpu = ($process | Measure-Object -Property CPU -Sum).Sum
    $ram = ($process | Measure-Object -Property WorkingSet64 -Sum).Sum

    $Samples += [PSCustomObject]@{
        Time     = Get-Date
        CPUTime  = $cpu
        RAMUsage = [Math]::Round($ram / 1MB, 2)  
    }

    Start-Sleep -Seconds $SampleInterval
}


$cpuDeltas = @()
$ramSamples = @()
$OutputData = @()

for ($i = 1; $i -lt $Samples.Count; $i++) {
    $deltaCPU = $Samples[$i].CPUTime - $Samples[$i - 1].CPUTime
    $deltaTime = ($Samples[$i].Time - $Samples[$i - 1].Time).TotalSeconds

    if ($deltaTime -gt 0) {
        $cpuUsage = ($deltaCPU / $deltaTime) * 100 / $ProcessorCount
        $cpuDeltas += $cpuUsage
    }

    $ramSamples += $Samples[$i].RAMUsage

    $OutputData += [PSCustomObject]@{
        Time        = $Samples[$i].Time.ToString("yyyy-MM-dd HH:mm:ss")
        CPU_Usage   = [Math]::Round($cpuUsage, 2)
        RAM_UsageMB = $Samples[$i].RAMUsage
    }
}

$averageCPU = [Math]::Round(($cpuDeltas | Measure-Object -Average).Average, 2)
$averageRAM = [Math]::Round(($ramSamples | Measure-Object -Average).Average, 2)

# Add final row with averages
$OutputData += [PSCustomObject]@{
    Time        = "Average"
    CPU_Usage   = $averageCPU
    RAM_UsageMB = $averageRAM
}


$OutputData | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8

Write-Host "Average CPU usage for '$ProcessName': $averageCPU% over $Duration seconds."
Write-Host "Average RAM usage for '$ProcessName': $averageRAM MB over $Duration seconds."
Write-Host "Results saved to $OutputPath"
