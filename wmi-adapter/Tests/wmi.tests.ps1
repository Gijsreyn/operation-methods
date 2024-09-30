# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'WMI adapter resource tests' {

    BeforeAll {
        if ($IsWindows)
        {
            $OldPSModulePath = $env:PSModulePath
            $env:PSModulePath += ";" + $PSScriptRoot

            $configPath = Join-path $PSScriptRoot "test_wmi_config.dsc.yaml"
        }
    }
    AfterAll {
        if ($IsWindows)
        {
            $env:PSModulePath = $OldPSModulePath
        }
    }

    Context 'List WMI resources' {
        It 'List shows WMI resources' -Skip:(!$IsWindows) {

            $r = dsc resource list *OperatingSystem* -a Microsoft.Windows/WMI
            $LASTEXITCODE | Should -Be 0
            $res = $r | ConvertFrom-Json
            $res.Count | Should -BeGreaterOrEqual 1
        }   
    }

    Context 'Get WMI resources' {
        It 'Get works on an individual WMI resource' -Skip:(!$IsWindows) {

            $r = dsc resource get -r root.cimv2/Win32_OperatingSystem
            $LASTEXITCODE | Should -Be 0
            $res = $r | ConvertFrom-Json
            $res.actualState.result.type | Should -BeLike "*Win32_OperatingSystem"
        }
    
        It 'Get works on a config with WMI resources' -Skip:(!$IsWindows) {
    
            $r = Get-Content -Raw $configPath | dsc config get
            $LASTEXITCODE | Should -Be 0
            $res = $r | ConvertFrom-Json
            $res.results.result.actualstate.result[0].properties.LastBootUpTime | Should -Not -BeNull
            $res.results.result.actualstate.result[0].properties.Caption | Should -Not -BeNull
            $res.results.result.actualstate.result[0].properties.NumberOfProcesses | Should -Not -BeNull
        }
    
        It 'Example config works' -Skip:(!$IsWindows) {
            $configPath = Join-Path $PSScriptRoot '..\..\dsc\examples\wmi.dsc.yaml'
            $r = dsc config get -p $configPath
            $LASTEXITCODE | Should -Be 0
            $r | Should -Not -BeNullOrEmpty
            $res = $r | ConvertFrom-Json
            $res.results.result.actualstate.result[0].properties.Model | Should -Not -BeNullOrEmpty
            $res.results.result.actualstate.result[0].properties.Description | Should -Not -BeNullOrEmpty
        }
    }

    # TODO: work on set test configs
    Context "Set WMI resources" {
        It 'Set a resource' -Skip:(!$IsWindows) {
            $inputs = @{
                adapted_dsc_type = "root.cimv2/Win32_Process"
                properties       = @{
                    MethodName  = 'Create'
                    CommandLine = 'powershell.exe'
                }
            }
            # get the start of processes
            $ref = Get-Process 

        $r = Get-Content -Raw $configPath | dsc config get
        $LASTEXITCODE | Should -Be 0
        $res = $r | ConvertFrom-Json
        $res.results[0].result.actualState[0].LastBootUpTime | Should -BeNullOrEmpty
        $res.results[0].result.actualState[0].Caption | Should -Not -BeNullOrEmpty
        $res.results[0].result.actualState[0].Version | Should -Not -BeNullOrEmpty
        $res.results[0].result.actualState[0].OSArchitecture | Should -Not -BeNullOrEmpty
    }

    It 'Example config works' -Skip:(!$IsWindows) {
        $configPath = Join-Path $PSScriptRoot '..\..\dsc\examples\wmi_inventory.dsc.yaml'
        $r = dsc config get -p $configPath
        $LASTEXITCODE | Should -Be 0
        $r | Should -Not -BeNullOrEmpty
        $res = $r | ConvertFrom-Json
        $res.results[0].result.actualState[0].Name | Should -Not -BeNullOrEmpty
        $res.results[0].result.actualState[0].BootupState | Should -BeNullOrEmpty
        $res.results[0].result.actualState[1].Caption | Should -Not -BeNullOrEmpty
        $res.results[0].result.actualState[1].BuildNumber | Should -BeNullOrEmpty
        $res.results[0].result.actualState[4].AdapterType | Should -BeLike "Ethernet*"
    }
}
