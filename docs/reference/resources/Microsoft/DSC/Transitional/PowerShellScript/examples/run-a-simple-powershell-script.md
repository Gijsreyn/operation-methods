---
description: >
  Example showing how to use the Microsoft.DSC.Transitional/PowerShellScript resource to run
  simple get, set, and test scripts and how PowerShell streams map to DSC log levels.
ms.date:     05/10/2026
ms.topic:    reference
title:       Run a simple PowerShell script
---

# Run a simple PowerShell script

This example shows how you can use the `Microsoft.DSC.Transitional/PowerShellScript` resource to
run inline PowerShell 7 scripts for **Get**, **Set**, and **Test** operations without passing any
input data.

## Get operation

The following snippet uses the [dsc resource get][01] command to execute a `getScript`. Any values
written to the PowerShell pipeline are collected and returned in the `output` array.

```powershell
$instance = @'
getScript: |
  "Hello, World!"
  1 + 1
'@

dsc resource get --resource Microsoft.DSC.Transitional/PowerShellScript --input $instance
```

```yaml
actualState:
  output:
    - Hello, World!
    - 2
```

Pipeline output is captured in order. Non-string values retain their type — `1 + 1` produces the
integer `2`, not the string `"2"`.

## Set operation

The following snippet uses the [dsc resource set][02] command to execute a `setScript`. The result
appears in `afterState.output`.

```powershell
$instance = @'
setScript: |
  "Hello, World!"
  1 + 1
'@

dsc resource set --resource Microsoft.DSC.Transitional/PowerShellScript --input $instance
```

```yaml
afterState:
  output:
    - Hello, World!
    - 2
```

## Test operation

The following snippets use the [dsc resource test][03] command to execute a `testScript`. The
`testScript` must return exactly one boolean value. DSC uses it to determine whether the instance
is in the desired state.

### Returning in desired state

```powershell
$instance = @'
testScript: |
  $true
'@

dsc resource test --resource Microsoft.DSC.Transitional/PowerShellScript --input $instance
```

```yaml
actualState:
  _inDesiredState: true
inDesiredState: true
differingProperties: []
```

### Returning out of desired state

```powershell
$instance = @'
testScript: |
  $false
'@

dsc resource test --resource Microsoft.DSC.Transitional/PowerShellScript --input $instance
```

```yaml
actualState:
  _inDesiredState: false
inDesiredState: false
differingProperties:
  - _inDesiredState
```

### Invalid test script output

If the `testScript` returns anything other than a single boolean — such as a string, a number, or
multiple values — DSC exits with code `2` and emits an error:

```plaintext
ERROR: Test operation did not return a single boolean value.
```

## Get and Set in the same instance

When both `getScript` and `setScript` are defined, `dsc resource set` runs `getScript` first to
capture `beforeState`, then runs `setScript` and captures `afterState`.

```powershell
$instance = @'
getScript: |
  "Hello, World!"
  1 + 1
setScript: |
  "Hello, World!"
  2 + 2
'@

dsc resource set --resource Microsoft.DSC.Transitional/PowerShellScript --input $instance
```

```yaml
beforeState:
  output:
    - Hello, World!
    - 2
afterState:
  output:
    - Hello, World!
    - 4
```

## Omitting scripts

Any script property that is absent or empty is silently ignored. For example, calling
`dsc resource get` when only `setScript` is defined returns an empty `output` array:

```yaml
actualState:
  output: []
```

If `testScript` is absent, the test operation returns `_inDesiredState: true` without executing
any script.

## PowerShell streams and DSC log levels

PowerShell stream cmdlets map to DSC log levels.

| PowerShell stream                              | DSC log level  | Example cmdlet            |
|:-----------------------------------------------|:---------------|:--------------------------|
| Error (`Write-Error`)                          | error (always) | `Write-Error "msg"`       |
| Warning (`Write-Warning`)                      | warn (always)  | `Write-Warning "msg"`     |
| Host / Verbose (`Write-Host`, `Write-Verbose`) | info           | `Write-Host "msg"`        |
| Debug (`Write-Debug`)                          | debug          | `Write-Debug "msg"`       |
| Information stream (`Write-Information`)       | trace          | `Write-Information "msg"` |

> [!NOTE]
> `Write-Error` causes the resource to exit with code `2`. `Write-Warning` does not affect the
> exit code.

A thrown exception also exits with code `2`:

```powershell
$instance = @'
getScript: |
  throw "This is an exception"
'@

dsc resource get --resource Microsoft.DSC.Transitional/PowerShellScript --input $instance
# Exit code: 2
# stderr: ERROR: This is an exception
```

<!-- Link definitions -->
[01]: ../../../../../../cli/resource/get.md
[02]: ../../../../../../cli/resource/set.md
[03]: ../../../../../../cli/resource/test.md
