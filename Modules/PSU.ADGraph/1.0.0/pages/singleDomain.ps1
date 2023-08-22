New-UDPage -Url "/singleDomain/:domain" -Name "singleDomain" -Content {
    Import-Module ADGraph
    # Use Get-UDPage -Name 'singleDomain' to use this page in your dashboard
    Write-PSFMessage -Level Host "### domain= $domain"
    # $domain=$Query.domain
    if ([string]::IsNullOrEmpty($Session:domainData)) {
        Write-PSFMessage "Lege neuen domainData-Sammler an"
        $Session:domainData = @{}
    }
    if ([string]::IsNullOrEmpty($Session:domainData.$domain)) {
        Write-PSFMessage "Ermittle Daten für $domain"
        $Session:domainData.$domain = (get-aduser -filter { name -like '*' } -Server $domain -Properties DistinguishedName, DisplayName, Description) + (Get-ADGroup -filter { name -like '*' } -Server $domain -Properties DistinguishedName, DisplayName, Description) | Select-Object -Property DistinguishedName, DisplayName, Description
        Write-PSFMessage "Anzahl Datensätze=$($Session:domainData.$domain.length)"
    }
    if ([string]::IsNullOrEmpty($Session:chosenData.$domain)) {
        Write-PSFMessage "Lege neuen Sammler für ausgewählte Einträge an"
        $Session:chosenData = @{}
    }
    if ([string]::IsNullOrEmpty($Session:chosenData.$domain)) {
        Write-PSFMessage "Lege neuen Sammler für ausgewählte Einträge der Domäne $domain an"
        $Session:chosenData.$domain = New-Object System.Collections.ArrayList
    }
    New-UDHeading -Text "Erstellung einer ADGraph PDF" -Size 2
    New-UDParagraph -Text "Bitte wählen Sie aus der ersten Liste der verfügbaren AD-Objekte diejenigen aus, die in der PDF aufgeführt werden sollen."
    New-UDGrid -Container -Content {
        New-UDGrid -Item -ExtraSmallSize 12 -Content {
            New-UDDynamic -Id "availableData" -Content {
                New-UDHeading -Size 3 -Text "Verfügbare AD Objekte"
                New-UDDataGrid -Height 200 -LoadRows {
                    Write-PSFMessage "LoadData, `$EventData=$($EventData|ConvertTo-Json -Compress)"
                    # $Rows = 1..100 | ForEach-Object {
                    #     @{ Name = 'Adam'; Number = Get-Random }
                    # }
                    # @{
                    #     rows     = $Rows | Select-Object -First $EventData.pageSize -Skip ($EventData.page * $EventData.pageSize)
                    #     rowCount = $Rows.Length
                    # }
                    if ([string]::IsNullOrEmpty($EventData.filter) -or ($EventData.filter.Items.count -eq 0 -and $EventData.filter.quickFilterValues.count -eq 0)) {
                        Write-PSFMessage "Kein Filter"
                        $rows = $Session:domainData.$domain | Select-Object -First $EventData.pageSize -Skip ($EventData.page * $EventData.pageSize)
                        $rowCount = $Session:domainData.$domain.length
                        Write-PSFMessage "Select -First $($EventData.pageSize) -Skip ($($EventData.page) * $($EventData.pageSize)), `$rows.length=$($rows.length)"
                    }
                    else {
                        $rows = $Session:domainData.$domain
                        # Write-PSFMessage "Filtern von ursprünglich $rows"
                        # $rows
                        if ($EventData.filter.Items.count -gt 0) {
                            Write-PSFMessage "Filtern nach Spalten"
                            $linkOperator = $EventData.Filter.linkOperator
                            $filterTextArray = @()
                            foreach ($filter in $EventData.Filter.Items) {
                                $property = $Filter.columnField
                                $val = $filter.Value
                                switch ($filter.operatorValue) {
                                    "contains" { $filterTextArray += "obj.$property -like ""*$val*""" }
                                    "equals" { $filterTextArray += "obj.$property -eq ""*$val*""" }
                                    "startsWith" { $filterTextArray += "obj.$property -like ""$val*""" }
                                    "endsWith" { $filterTextArray += "obj.$property -like ""*$val""" }
                                    "isAnyOf" { $filterTextArray += "obj.$property -in ""$val""" }
                                    "notequals" { $filterTextArray += "obj.$property -ne ""$val""" }
                                    "notcontains" { $filterTextArray += "obj.$property -notlike ""*$val*""" }
                                    "isEmpty" { $filterTextArray += "obj.$property -eq null" }
                                    "isNotEmpty" { $filterTextArray += "obj.$property -ne null" }
                                }
                            }
                            if ($linkOperator -eq 'and') {
                                [string]$filterTextLine = $filterTextArray -join " -and "
                            }
                            else {
                                [string]$filterTextLine = $filterTextArray -join " -or "
                            }

                            $filterTextLine = $filterTextLine.Replace('obj', '$_')
                            $filterTextLine = $filterTextLine.Replace('null', '$null')
                            Write-PSFMessage "`$filterTextLine=$filterTextLine"

                            $filterScriptBlock = [Scriptblock]::Create($filterTextLine)
                            $rows = $rows | Where-Object -FilterScript $filterScriptBlock #| Select-Object -First $EventData.pageSize -Skip ($EventData.page * $EventData.pageSize)
                        }
                        if ($EventData.filter.quickFilterValues.count -gt 0) {
                            Write-PSFMessage "Filtern nach QuickFilter"
                            $regex = $EventData.filter.quickFilterValues | Join-String -Separator '|'
                            $regex = "DistinguishedName", "DisplayName", "Description" | ForEach-Object { "`$_.$_ -match '$regex'" } | Join-String -Separator " -or "
                            Write-PSFMessage "QuickFilter=$regex"
                            $rows = $rows | Where-Object -FilterScript ([Scriptblock]::Create($regex))
                            Write-PSFMessage "Anzahl Zeilen: $($rows.count)"
                            if ($rows.count -lt 5) {
                                Write-PSFMessage "Rows=$($rows |ConvertTo-Json -Compress)"
                            }
                        }

                        $Sort = $EventData.Sort[0]
                        $rows = $rows | Sort-Object -Property $Sort.field -Descending:$($Sort.Sort -eq 'desc')
                        $rowCount = $rows.length
                        $rows = $rows | Select-Object -Skip ($EventData.Page * $EventData.pageSize) -First $EventData.PageSize
                        # $Items = $Items | Where-Object -FilterScript $filterScriptBlock
                    }

                    $data = @{
                        rows     = @() + $rows #$Session:domainData.$domain| Select-Object -First $EventData.pageSize -Skip ($EventData.page * $EventData.pageSize)
                        rowCount = $rowCount
                    }
                    Write-PSFMessage "Rows=$($rows |Select-Object -First 2|ConvertTo-Json -Compress)"
                    Write-PSFMessage "rowCount=$rowCount"

                    $data
                } -Columns @(
                    # @{ field = "name"; } #render = { New-UDTypography $EventData.number } }
                    # @{ field = "number"; flex = 1.0 }
                    @{ field = "DistinguishedName"; flex = 40 ; render = {
                            New-UDLink -Text $EventData.DistinguishedName -OnClick {
                                Write-PSFMessage "Type=$($Session:chosenData.$domain.GetType())"
                                $Session:chosenData.$domain.add(($EventData | ConvertTo-PSFHashtable -Include DistinguishedName, DisplayName, Description))
                                Write-PSFMessage "Type=$($Session:chosenData.$domain.GetType())"
                                # $Session:chosenData.$domain.rowCount +=1
                                Sync-UDElement -Id "chosenData"
                                Write-PSFMessage ($EventData | ConvertTo-Json -Compress)
                            } # -url "/fortigateExports/$($EventData.Name)"
                        }
                    }
                    @{ field = "DisplayName" ; flex = 20 }
                    @{ field = "Description" ; flex = 40 }
                ) -AutoHeight $true -PageSize 30 -ShowPagination -ShowQuickFilter
                # }     -AutoHeight -Pagination
                # -Columns @(
                #     @{ field = "name"; }
                #     @{ field = "number" }
                # )
            }
        }
        New-UDGrid -Item -ExtraSmallSize 12 -Content {
            New-UDHeading -Size 3 -Text "Gewählte AD Objekte"
            New-UDDynamic -Id "chosenData" -Content {
                New-UDTable -Data $Session:chosenData.$domain -Columns @(
                    New-UDTableColumn  -Property DistinguishedName -Title DistinguishedName -Render {
                        New-UDLink -Text $EventData.DistinguishedName -OnClick {
                            Write-PSFMessage ($EventData | ConvertTo-Json -Compress)
                            $keepEntries = $Session:chosenData.$domain.Where({ $_.DistinguishedName -ne $EventData.DistinguishedName })
                            $Session:chosenData.$domain.clear()
                            $Session:chosenData.$domain.addrange($keepEntries)
                            # $Session:chosenData.$domain.add(($EventData | ConvertTo-PSFHashtable -Include DistinguishedName, DisplayName, Description))
                            Sync-UDElement -Id "chosenData"
                        }
                    }
                    New-UDTableColumn  -Property DisplayName -Title DisplayName
                    New-UDTableColumn  -Property Description -Title Description
                )
            }
            New-UDGrid -Item -ExtraSmallSize 3 -Content {
                New-UDCheckbox -Id 'chkUser' -Label "User einbinden" -Checked $true
                New-UDCheckbox -Id 'chkMemberOf' -Label "MemberOf anzeigen" -Checked $true
                New-UDCheckbox -Id 'chkMember' -Label "Member anzeigen" -Checked $true
                New-UDButton -Id "createGraph" -Text "Create PDF" -OnClick {
                    $element = Get-UDElement -Id chosenData # -Property checked
                    Write-PSFMessage "`chosenData=$($element|ConvertTo-Json -Compress)"
                    $newADGraphOptions = @{
                        Domain            = $domain
                        DistinguishedName = $Session:chosenData.$domain.DistinguishedName
                        MemberOf          = Get-UDElement -Id chkMemberOf -Property checked
                        Members           = Get-UDElement -Id chkMember -Property checked
                        Users             = Get-UDElement -Id chkUser -Property checked
                        ReturnType        = "SingleGraph"
                        #Path              = "d:\PSUData\Repository\adGraphOut"
                        WarningAction     = "SilentlyContinue"
                        ErrorAction       = "SilentlyContinue"
                    }
                    Write-PSFMessage "`$newADGraphOptions=$($newADGraphOptions|ConvertTo-Json -Compress)"
                    $myGraphArray = New-ADGraph @newADGraphOptions
                    # Write-PSFMessage "`$myGraphArray=$($myGraphArray)"
                    $tempFileName = New-TemporaryFile
                    $pdfFileName = "$((New-Guid).Guid).pdf"
                    $myGraphArray | Out-File -Encoding utf8 -path $tempFileName
                    Write-PSFMessage "Erzeuge $pdfFileName"
                    $outPath = Get-PSFConfigValue -FullName 'PSU.ADGraph.PublishedFolders.outpath'

                    Export-PSGraph -OutputFormat pdf -DestinationPath "$outPath\$pdfFileName" -Source $tempFileName
                    Invoke-UDRedirect "/adgraph/out/$pdfFileName" -Native -OpenInNewWindow
                }
                # New-UDForm -Content {
                # } -OnSubmit {
                # Show-UDToast -Message $EventData.txtTextField
                # Show-UDToast -Message $EventData.chkCheckbox
                # }
            }
        }
    }
} -Title "Abfrage der Einzel-Domäne"