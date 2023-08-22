function New-PSUADGraphApp {
    Write-Host "Initializing App"
    # Put code you'd like to run during dashboard startup here.
    New-UDDashboard -Title 'PowerShell Universal' -Pages @(
        # Create a page using the menu to the right ->
        # Reference the page here with Get-UDPage
        New-UDPage -Name 'Home' -Content {
            New-UDHeading -Size 2 -Content { "Hello World" }
            New-UDParagraph -Content { "This works" }
        }
    )
}