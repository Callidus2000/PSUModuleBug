# New-PSUScript -Module "PSU.ADGraph" -Command "Remove-PSUADExports" -InformationAction "SilentlyContinue" -Description "Removes all exported ADGraphs older than 30min"
New-PSUScript -Module 'PSU.ADGraph' -Command 'Remove-PSUADExports'
New-PSUScript -Module 'PSU.ADGraph' -Command 'Remove-PSUADExportsNoDotSource'