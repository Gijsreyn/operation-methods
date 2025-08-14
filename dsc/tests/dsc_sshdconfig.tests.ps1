# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
BeforeDiscovery {
    if ($IsWindows) {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [System.Security.Principal.WindowsPrincipal]::new($identity)
        $isElevated = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
        $sshdExists = ($null -ne (Get-Command sshd -CommandType Application -ErrorAction Ignore))
        $skipTest = !$isElevated -or !$sshdExists
    }
}

Describe 'SSHDConfig resource tests' -Skip:(!$IsWindows -or $skipTest) {
    BeforeAll {
        # set a non-default value in a temporary sshd_config file
        "LogLevel Debug3`nPasswordAuthentication no" | Set-Content -Path $TestDrive/test_sshd_config
        $filepath = Join-Path $TestDrive 'test_sshd_config'
        $yaml = @"
`$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
metadata:
  Microsoft.DSC:
    securityContext: elevated
resources:
- name: sshdconfig
  type: Microsoft.OpenSSH.SSHD/sshd_config
  properties:
    _metadata:
      filepath: $filepath
"@
    }

    It '<command> works' -TestCases @(
        @{ command = 'get' }
        @{ command = 'export' }
    ) {
        param($command)
        $out = dsc config $command -i "$yaml" | ConvertFrom-Json -Depth 10
        $LASTEXITCODE | Should -Be 0
        if ($command -eq 'export') {
            $out.resources.count | Should -Be 1
            $out.resources[0].properties | Should -Not -BeNullOrEmpty
            $out.resources[0].properties.port | Should -BeNullOrEmpty
            $out.resources[0].properties.passwordAuthentication | Should -Be 'no'
            $out.resources[0].properties._inheritedDefaults | Should -BeNullOrEmpty
        } else {
            $out.results.count | Should -Be 1
            $out.results.result.actualState | Should -Not -BeNullOrEmpty
            $out.results.result.actualState.port[0] | Should -Be 22
            $out.results.result.actualState.passwordAuthentication | Should -Be 'no'
            $out.results.result.actualState._inheritedDefaults | Should -Contain 'port'
        }
    }

    It 'Export with filter works' {
        $export_yaml = @"
`$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
metadata:
    Microsoft.DSC:
        securityContext: elevated
resources:
- name: sshdconfig
  type: Microsoft.OpenSSH.SSHD/sshd_config
  properties:
    passwordauthentication: 'yes'
    _metadata:
      filepath: $filepath
"@
        $out = dsc config export -i "$export_yaml" | ConvertFrom-Json -Depth 10
        $LASTEXITCODE | Should -Be 0
        $out.resources.count | Should -Be 1
        ($out.resources[0].properties.psobject.properties | Measure-Object).count | Should -Be 1
        $out.resources[0].properties.passwordAuthentication | Should -Be 'no'
    }

    It '<command> with _includeDefaults specified works' -TestCases @(
        @{ command = 'get'; includeDefaults = $false }
        @{ command = 'export'; includeDefaults = $true }
    ) {
        param($command, $includeDefaults)
        $filepath = Join-Path $TestDrive 'test_sshd_config'
        $input = @"
`$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
metadata:
  Microsoft.DSC:
    securityContext: elevated
resources:
- name: sshdconfig
  type: Microsoft.OpenSSH.SSHD/sshd_config
  properties:
    _includeDefaults: $includeDefaults
    _metadata:
        filepath: $filepath
"@
        $out = dsc config $command -i "$input" | ConvertFrom-Json -Depth 10
        $LASTEXITCODE | Should -Be 0
        if ($command -eq 'export') {
            $out.resources.count | Should -Be 1
            $out.resources[0].properties.loglevel | Should -Be 'debug3'
            $out.resources[0].properties.port | Should -Be 22
            $out.resources[0].properties._inheritedDefaults | Should -BeNullOrEmpty
        } else {
            $out.results.count | Should -Be 1
            ($out.results.result.actualState.psobject.properties | Measure-Object).count | Should -Be 2
            $out.results.result.actualState.loglevel | Should -Be 'debug3'
            $out.results.result.actualState._inheritedDefaults | Should -BeNullOrEmpty
        }
    }

    Context 'Surface a default value that has been set in file' {
        BeforeAll {
            "Port 22" | Set-Content -Path $TestDrive/test_sshd_config
        }

        It '<command> works' -TestCases @(
            @{ command = 'get' }
            @{ command = 'export' }
        ) {
            param($command)
            $out = dsc config $command -i "$yaml" | ConvertFrom-Json -Depth 10
            $LASTEXITCODE | Should -Be 0
            if ($command -eq 'export') {
                $out.resources.count | Should -Be 1
                $out.resources[0].properties | Should -Not -BeNullOrEmpty
                $out.resources[0].properties.port[0] | Should -Be 22
                $out.resources[0].properties.passwordauthentication | Should -BeNullOrEmpty
                $out.resources[0].properties._inheritedDefaults | Should -BeNullOrEmpty
            } else {
                $out.results.count | Should -Be 1
                $out.results.result.actualState | Should -Not -BeNullOrEmpty
                $out.results.result.actualState.port | Should -Be 22
                $out.results.result.actualState.passwordAuthentication | Should -Be 'yes'
                $out.results.result.actualState._inheritedDefaults | Should -Not -Contain 'port'
            }
        }
    }
}
