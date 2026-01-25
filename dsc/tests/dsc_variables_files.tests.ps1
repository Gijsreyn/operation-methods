# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'Variables Files tests' {
    BeforeAll {
        # Create test variables files
        $script:testDir = Join-Path $TestDrive 'variables_files_tests'
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
    }

    Context 'Document-level variablesFiles property' {
        It 'Loads variables from a YAML file' {
            $variablesYaml = @"
serverPort: 8080
serverName: test-server
"@
            $variablesPath = Join-Path $script:testDir 'variables.yaml'
            Set-Content -Path $variablesPath -Value $variablesYaml

            $configYaml = @"
`$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
variablesFiles:
  - $($variablesPath -replace '\\', '/')
resources:
  - name: Echo
    type: Microsoft.DSC.Debug/Echo
    properties:
      output: "[variables('serverPort')]"
"@
            $configPath = Join-Path $script:testDir 'config.dsc.yaml'
            Set-Content -Path $configPath -Value $configYaml

            $out = dsc config get -f $configPath | ConvertFrom-Json
            $LASTEXITCODE | Should -Be 0
            $out.results[0].result.actualState.output | Should -Be 8080
        }

        It 'Loads variables from a JSON file' {
            $variablesJson = @{
                serverPort = 9090
                serverName = 'json-server'
            } | ConvertTo-Json
            $variablesPath = Join-Path $script:testDir 'variables.json'
            Set-Content -Path $variablesPath -Value $variablesJson

            $configYaml = @"
`$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
variablesFiles:
  - $($variablesPath -replace '\\', '/')
resources:
  - name: Echo
    type: Microsoft.DSC.Debug/Echo
    properties:
      output: "[variables('serverPort')]"
"@
            $configPath = Join-Path $script:testDir 'config_json.dsc.yaml'
            Set-Content -Path $configPath -Value $configYaml

            $out = dsc config get -f $configPath | ConvertFrom-Json
            $LASTEXITCODE | Should -Be 0
            $out.results[0].result.actualState.output | Should -Be 9090
        }

        It 'Loads variables from a YML file' {
            $variablesYml = @"
port: 7070
"@
            $variablesPath = Join-Path $script:testDir 'variables.yml'
            Set-Content -Path $variablesPath -Value $variablesYml

            $configYaml = @"
`$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
variablesFiles:
  - $($variablesPath -replace '\\', '/')
resources:
  - name: Echo
    type: Microsoft.DSC.Debug/Echo
    properties:
      output: "[variables('port')]"
"@
            $configPath = Join-Path $script:testDir 'config_yml.dsc.yaml'
            Set-Content -Path $configPath -Value $configYaml

            $out = dsc config get -f $configPath | ConvertFrom-Json
            $LASTEXITCODE | Should -Be 0
            $out.results[0].result.actualState.output | Should -Be 7070
        }

        It 'Later files override earlier files' {
            $variables1 = @"
value: first
shared: from-first
"@
            $variables2 = @"
value: second
"@
            $vars1Path = Join-Path $script:testDir 'vars1.yaml'
            $vars2Path = Join-Path $script:testDir 'vars2.yaml'
            Set-Content -Path $vars1Path -Value $variables1
            Set-Content -Path $vars2Path -Value $variables2

            $configYaml = @"
`$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
variablesFiles:
  - $($vars1Path -replace '\\', '/')
  - $($vars2Path -replace '\\', '/')
resources:
  - name: Echo
    type: Microsoft.DSC.Debug/Echo
    properties:
      output: "[variables('value')]"
"@
            $configPath = Join-Path $script:testDir 'config_override.dsc.yaml'
            Set-Content -Path $configPath -Value $configYaml

            $out = dsc config get -f $configPath | ConvertFrom-Json
            $LASTEXITCODE | Should -Be 0
            $out.results[0].result.actualState.output | Should -BeExactly 'second'
        }

        It 'Inline variables override file variables' {
            $variablesYaml = @"
value: from-file
"@
            $variablesPath = Join-Path $script:testDir 'vars_inline_test.yaml'
            Set-Content -Path $variablesPath -Value $variablesYaml

            $configYaml = @"
`$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
variablesFiles:
  - $($variablesPath -replace '\\', '/')
variables:
  value: from-inline
resources:
  - name: Echo
    type: Microsoft.DSC.Debug/Echo
    properties:
      output: "[variables('value')]"
"@
            $configPath = Join-Path $script:testDir 'config_inline_override.dsc.yaml'
            Set-Content -Path $configPath -Value $configYaml

            $out = dsc config get -f $configPath | ConvertFrom-Json
            $LASTEXITCODE | Should -Be 0
            $out.results[0].result.actualState.output | Should -BeExactly 'from-inline'
        }

        It 'Supports nested object variables' {
            $variablesYaml = @"
database:
  host: localhost
  port: 5432
"@
            $variablesPath = Join-Path $script:testDir 'nested_vars.yaml'
            Set-Content -Path $variablesPath -Value $variablesYaml

            $configYaml = @"
`$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
variablesFiles:
  - $($variablesPath -replace '\\', '/')
resources:
  - name: Echo
    type: Microsoft.DSC.Debug/Echo
    properties:
      output: "[variables('database').host]"
"@
            $configPath = Join-Path $script:testDir 'config_nested.dsc.yaml'
            Set-Content -Path $configPath -Value $configYaml

            $out = dsc config get -f $configPath | ConvertFrom-Json
            $LASTEXITCODE | Should -Be 0
            $out.results[0].result.actualState.output | Should -BeExactly 'localhost'
        }
    }

    Context 'CLI --variables-file option' {
        It 'Loads variables from CLI option' {
            $variablesYaml = @"
cliValue: from-cli-file
"@
            $variablesPath = Join-Path $script:testDir 'cli_vars.yaml'
            Set-Content -Path $variablesPath -Value $variablesYaml

            $configYaml = @"
`$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
resources:
  - name: Echo
    type: Microsoft.DSC.Debug/Echo
    properties:
      output: "[variables('cliValue')]"
"@
            $configPath = Join-Path $script:testDir 'config_cli.dsc.yaml'
            Set-Content -Path $configPath -Value $configYaml

            $out = dsc config --variables-file $variablesPath get -f $configPath | ConvertFrom-Json
            $LASTEXITCODE | Should -Be 0
            $out.results[0].result.actualState.output | Should -BeExactly 'from-cli-file'
        }

        It 'Multiple CLI variables files are processed in order' {
            $vars1 = @"
value: first
other: from-first
"@
            $vars2 = @"
value: second
"@
            $vars1Path = Join-Path $script:testDir 'cli_vars1.yaml'
            $vars2Path = Join-Path $script:testDir 'cli_vars2.yaml'
            Set-Content -Path $vars1Path -Value $vars1
            Set-Content -Path $vars2Path -Value $vars2

            $configYaml = @"
`$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
resources:
  - name: Echo
    type: Microsoft.DSC.Debug/Echo
    properties:
      output: "[variables('value')]"
"@
            $configPath = Join-Path $script:testDir 'config_multi_cli.dsc.yaml'
            Set-Content -Path $configPath -Value $configYaml

            $out = dsc config --variables-file $vars1Path --variables-file $vars2Path get -f $configPath | ConvertFrom-Json
            $LASTEXITCODE | Should -Be 0
            $out.results[0].result.actualState.output | Should -BeExactly 'second'
        }

        It 'CLI variables override document-level variablesFiles and inline variables' {
            $docVars = @"
value: from-doc-file
"@
            $cliVars = @"
value: from-cli-file
"@
            $docVarsPath = Join-Path $script:testDir 'doc_vars_precedence.yaml'
            $cliVarsPath = Join-Path $script:testDir 'cli_vars_precedence.yaml'
            Set-Content -Path $docVarsPath -Value $docVars
            Set-Content -Path $cliVarsPath -Value $cliVars

            $configYaml = @"
`$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
variablesFiles:
  - $($docVarsPath -replace '\\', '/')
variables:
  value: from-inline
resources:
  - name: Echo
    type: Microsoft.DSC.Debug/Echo
    properties:
      output: "[variables('value')]"
"@
            $configPath = Join-Path $script:testDir 'config_precedence.dsc.yaml'
            Set-Content -Path $configPath -Value $configYaml

            $out = dsc config --variables-file $cliVarsPath get -f $configPath | ConvertFrom-Json
            $LASTEXITCODE | Should -Be 0
            $out.results[0].result.actualState.output | Should -BeExactly 'from-cli-file'
        }

        It 'Short form -v works for variables file' {
            $variablesYaml = @"
shortValue: short-form-works
"@
            $variablesPath = Join-Path $script:testDir 'short_vars.yaml'
            Set-Content -Path $variablesPath -Value $variablesYaml

            $configYaml = @"
`$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
resources:
  - name: Echo
    type: Microsoft.DSC.Debug/Echo
    properties:
      output: "[variables('shortValue')]"
"@
            $configPath = Join-Path $script:testDir 'config_short.dsc.yaml'
            Set-Content -Path $configPath -Value $configYaml

            $out = dsc config -v $variablesPath get -f $configPath | ConvertFrom-Json
            $LASTEXITCODE | Should -Be 0
            $out.results[0].result.actualState.output | Should -BeExactly 'short-form-works'
        }
    }

    Context 'Error handling' {
        It 'Fails when variables file does not exist' {
            $configYaml = @"
`$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
variablesFiles:
  - nonexistent_file.yaml
resources:
  - name: Echo
    type: Microsoft.DSC.Debug/Echo
    properties:
      output: hello
"@
            $configPath = Join-Path $script:testDir 'config_missing_file.dsc.yaml'
            Set-Content -Path $configPath -Value $configYaml

            $testError = & { dsc config get -f $configPath 2>&1 }
            $testError | Should -Match 'Variables file not found'
            $LASTEXITCODE | Should -Not -Be 0
        }

        It 'Fails when variables file has invalid extension' {
            $variablesPath = Join-Path $script:testDir 'variables.txt'
            Set-Content -Path $variablesPath -Value 'value: test'

            $configYaml = @"
`$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
variablesFiles:
  - $($variablesPath -replace '\\', '/')
resources:
  - name: Echo
    type: Microsoft.DSC.Debug/Echo
    properties:
      output: hello
"@
            $configPath = Join-Path $script:testDir 'config_bad_ext.dsc.yaml'
            Set-Content -Path $configPath -Value $configYaml

            $testError = & { dsc config get -f $configPath 2>&1 }
            $testError | Should -Match 'Invalid variables file extension'
            $LASTEXITCODE | Should -Not -Be 0
        }

        It 'Fails when variables file contains invalid YAML/JSON' {
            $invalidContent = @"
this is not valid: yaml: content:::
  - broken
    indentation
"@
            $variablesPath = Join-Path $script:testDir 'invalid_vars.yaml'
            Set-Content -Path $variablesPath -Value $invalidContent

            $configYaml = @"
`$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
variablesFiles:
  - $($variablesPath -replace '\\', '/')
resources:
  - name: Echo
    type: Microsoft.DSC.Debug/Echo
    properties:
      output: hello
"@
            $configPath = Join-Path $script:testDir 'config_invalid_yaml.dsc.yaml'
            Set-Content -Path $configPath -Value $configYaml

            $testError = & { dsc config get -f $configPath 2>&1 }
            $testError | Should -Match 'Failed to parse variables file'
            $LASTEXITCODE | Should -Not -Be 0
        }

        It 'Fails when variables file path contains parent directory reference' {
            $configYaml = @"
`$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
variablesFiles:
  - ../parent_dir/variables.yaml
resources:
  - name: Echo
    type: Microsoft.DSC.Debug/Echo
    properties:
      output: hello
"@
            $configPath = Join-Path $script:testDir 'config_parent_dir.dsc.yaml'
            Set-Content -Path $configPath -Value $configYaml

            $testError = & { dsc config get -f $configPath 2>&1 }
            $testError | Should -Match "must not contain '\.\.'"
            $LASTEXITCODE | Should -Not -Be 0
        }
    }

    Context 'Relative path resolution' {
        It 'Resolves relative paths from configuration file location' {
            # Create subdirectory structure
            $subDir = Join-Path $script:testDir 'subdir'
            $varsDir = Join-Path $script:testDir 'vars'
            New-Item -ItemType Directory -Path $subDir -Force | Out-Null
            New-Item -ItemType Directory -Path $varsDir -Force | Out-Null

            $variablesYaml = @"
relativeValue: resolved-correctly
"@
            $variablesPath = Join-Path $varsDir 'rel_vars.yaml'
            Set-Content -Path $variablesPath -Value $variablesYaml

            # Config uses relative path to variables file
            $configYaml = @"
`$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
variablesFiles:
  - vars/rel_vars.yaml
resources:
  - name: Echo
    type: Microsoft.DSC.Debug/Echo
    properties:
      output: "[variables('relativeValue')]"
"@
            $configPath = Join-Path $script:testDir 'config_relative.dsc.yaml'
            Set-Content -Path $configPath -Value $configYaml

            $out = dsc config get -f $configPath | ConvertFrom-Json
            $LASTEXITCODE | Should -Be 0
            $out.results[0].result.actualState.output | Should -BeExactly 'resolved-correctly'
        }
    }

    Context 'Combined with other features' {
        It 'Variables from files work with parameters' {
            $variablesYaml = @"
prefix: hello
"@
            $variablesPath = Join-Path $script:testDir 'combined_vars.yaml'
            Set-Content -Path $variablesPath -Value $variablesYaml

            $configYaml = @"
`$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
variablesFiles:
  - $($variablesPath -replace '\\', '/')
parameters:
  suffix:
    type: string
resources:
  - name: Echo
    type: Microsoft.DSC.Debug/Echo
    properties:
      output: "[concat(variables('prefix'), '-', parameters('suffix'))]"
"@
            $configPath = Join-Path $script:testDir 'config_combined.dsc.yaml'
            Set-Content -Path $configPath -Value $configYaml

            $params = @{ parameters = @{ suffix = 'world' }} | ConvertTo-Json
            $out = dsc config -p $params get -f $configPath | ConvertFrom-Json
            $LASTEXITCODE | Should -Be 0
            $out.results[0].result.actualState.output | Should -BeExactly 'hello-world'
        }
    }
}
