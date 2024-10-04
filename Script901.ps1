# Function to get all VMs with their status, CPU usage, and disk space
$subscriptionId = ""
Set-AzContext -SubscriptionId $subscriptionId
function Get-AzVMStatus {
    try {
        $vms = Get-AzVM -Status
        if (!$vms) {
            Write-Output "No Virtual Machines found."
            return
        }
        $vmData = @()
        
        foreach ($vm in $vms) {
            $status = ($vm.Statuses | Where-Object { $_.Code -like "PowerState/*" }).DisplayStatus
            $cpuUsage = (Get-AzMetric -ResourceId $vm.Id -MetricName "Percentage CPU").Data | Select-Object -Last 1 -ExpandProperty Average
            $diskSpace = (Get-AzMetric -ResourceId $vm.Id -MetricName "Disk Read Bytes").Data | Select-Object -Last 1 -ExpandProperty Total
            $vmData += [pscustomobject]@{
                Name       = $vm.Name
                Status     = $status
                CPUUsage   = $cpuUsage
                DiskSpace  = $diskSpace
            }
        }
        return $vmData
    } catch {
        Write-Output "Error gathering VM data: $_"
    }
}

# Function to get metrics for App Services
function Get-AzAppServiceMetrics {
    try {
        $appServices = Get-AzWebApp
        if (!$appServices) {
            Write-Output "No App Services found."
            return
        }
        $appServiceData = @()
        
        foreach ($appService in $appServices) {
            $cpuUsage = (Get-AzMetric -ResourceId $appService.Id -MetricName "CPU Percentage").Data | Select-Object -Last 1 -ExpandProperty Average
            $memoryUsage = (Get-AzMetric -ResourceId $appService.Id -MetricName "Memory Working Set").Data | Select-Object -Last 1 -ExpandProperty Average
            $appServiceData += [pscustomobject]@{
                Name        = $appService.Name
                CPUUsage    = $cpuUsage
                MemoryUsage = $memoryUsage
            }
        }
        return $appServiceData
    } catch {
        Write-Output "Error gathering App Service data: $_"
    }
}

# Function to get metrics for Container Apps
function Get-AzContainerAppMetrics {
    try {
        $containerApps = Get-AzContainerGroup
        if (!$containerApps) {
            Write-Output "No Container Apps found."
            return
        }
        $containerAppData = @()
        
        foreach ($containerApp in $containerApps) {
            $cpuUsage = (Get-AzMetric -ResourceId $containerApp.Id -MetricName "CPU Usage").Data | Select-Object -Last 1 -ExpandProperty Average
            $memoryUsage = (Get-AzMetric -ResourceId $containerApp.Id -MetricName "Memory Usage").Data | Select-Object -Last 1 -ExpandProperty Average
            $containerAppData += [pscustomobject]@{
                Name        = $containerApp.Name
                CPUUsage    = $cpuUsage
                MemoryUsage = $memoryUsage
            }
        }
        return $containerAppData
    } catch {
        Write-Output "Error gathering Container App data: $_"
    }
}

# Function to get metrics for Storage Accounts
function Get-AzStorageAccountMetrics {
    try {
        $storageAccounts = Get-AzStorageAccount
        if (!$storageAccounts) {
            Write-Output "No Storage Accounts found."
            return
        }
        $storageAccountData = @()
        
        foreach ($storageAccount in $storageAccounts) {
            $transactionCount = (Get-AzMetric -ResourceId $storageAccount.Id -MetricName "Transactions").Data | Select-Object -Last 1 -ExpandProperty Total
            $storageAccountData += [pscustomobject]@{
                Name            = $storageAccount.StorageAccountName
                TransactionCount = $transactionCount
            }
        }
        return $storageAccountData
    } catch {
        Write-Output "Error gathering Storage Account data: $_"
    }
}

# Function to calculate cost for all resources by type
function Get-AzResourceCostEstimate {
    try {
        $resourceTypes = @("Microsoft.Compute/virtualMachines", "Microsoft.Web/sites", "Microsoft.ContainerInstance/containerGroups", "Microsoft.Storage/storageAccounts")
        $resourceCosts = @()

        # Set date range for the last 30 days
        $startDate = (Get-Date).AddDays(-30).ToString("yyyy-MM-dd")
        $endDate = (Get-Date).ToString("yyyy-MM-dd")

        foreach ($type in $resourceTypes) {
            $resources = Get-AzResource -ResourceType $type
            if (!$resources) {
                Write-Output "No resources found for type: $type"
                continue
            }
            $typeTotalCost = 0
            
            foreach ($resource in $resources) {
                try {
                    # Retrieve usage details for the resource within the date range
                    $usageDetails = Get-AzConsumptionUsageDetail -ResourceId $resource.Id -StartDate $startDate -EndDate $endDate -ErrorAction Stop

                    # Explore potential cost properties
                    $cost = $usageDetails.Properties.pretaxCost
                    if (-not $cost) {
                        $cost = $usageDetails.Properties.billingCurrencyTotal
                    }
                    if (-not $cost) {
                        $cost = $usageDetails.Properties.costInBillingCurrency
                    }

                    if ($cost) {
                        $typeTotalCost += $cost
                    } else {
                        Write-Output "No cost data for resource $($resource.Name)"
                    }

                } catch {
                    Write-Output "Error fetching cost for resource $($resource.Name) of type ${type}: $_"
                }
            }

            # Collect total cost for each resource type
            $resourceCosts += [pscustomobject]@{
                ResourceType = $type
                TotalCost    = $typeTotalCost
            }
        }
        return $resourceCosts
    } catch {
        Write-Output "Error calculating resource costs: $_"
    }
}

# Script Execution
$vmStatus = Get-AzVMStatus
$appServiceMetrics = Get-AzAppServiceMetrics
$containerAppMetrics = Get-AzContainerAppMetrics
$storageAccountMetrics = Get-AzStorageAccountMetrics
$resourceCosts = Get-AzResourceCostEstimate

# Output results
Write-Output "VM Status:"
$vmStatus | Format-Table -AutoSize

Write-Output "App Service Metrics:"
$appServiceMetrics | Format-Table -AutoSize

Write-Output "Container App Metrics:"
$containerAppMetrics | Format-Table -AutoSize

Write-Output "Storage Account Metrics:"
$storageAccountMetrics | Format-Table -AutoSize

Write-Output "Resource Cost Estimates:"
$resourceCosts | Format-Table -AutoSize
