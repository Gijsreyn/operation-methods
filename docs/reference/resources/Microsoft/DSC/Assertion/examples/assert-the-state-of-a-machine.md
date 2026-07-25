---
description: >-
  Demonstrates how to define a standalone assertion with the Microsoft.DSC/Assertion resource and
  interpret a passing and failing result.
ms.date:     07/24/2026
ms.topic:    reference
title:       Assert the state of a machine
---

This example demonstrates how to use the `Microsoft.DSC/Assertion` resource to verify that a machine
is in an expected state. The assertion never changes the system. It only reports whether the nested
resource instances are already in the desired state.

## Define the assertion

Author a configuration document with a single `Microsoft.DSC/Assertion` instance. The assertion's
properties are themselves a configuration document. This example asserts that the operating system
family is `Windows` by using the `Microsoft/OSInfo` resource.

```yaml
# assert-os.dsc.yaml
$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
resources:
  - name: assert environment
    type: Microsoft.DSC/Assertion
    properties:
      $schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
      resources:
        - name: os
          type: Microsoft/OSInfo
          properties:
            family: Windows
```

## Test a passing assertion

Invoke the [dsc config test][01] command against the document. DSC runs the **Test** operation for
each nested instance and reports the result.

```powershell
dsc config test --file ./assert-os.dsc.yaml
```

On a Windows machine, the nested `Microsoft/OSInfo` instance is in the desired state, so the
assertion succeeds and the command exits with code `0`. The output is similar to the following YAML:

```yaml
results:
- name: assert environment
  type: Microsoft.DSC/Assertion
  result:
  - name: os
    type: Microsoft/OSInfo
    result:
      desiredState:
        family: Windows
      actualState:
        $id: https://aka.ms/dsc/schemas/v3/bundled/resource/manifest.json
        family: Windows
        version: 10.0.26100
        bitness: '64'
      inDesiredState: true
      differingProperties: []
messages: []
hadErrors: false
```

## Test a failing assertion

When the machine doesn't match the asserted state, the assertion fails. For example, running the
same document on a Linux or macOS machine causes the `family` property to differ from the expected
value.

```powershell
dsc config test --file ./assert-os.dsc.yaml
```

DSC reports an `Assertion failed` error, writes the details to the error stream, and the command
exits with a non-zero exit code:

```Output
ERROR ... Assertion failed ...
```

> [!TIP]
> Because the `Microsoft.DSC/Assertion` resource always tests and never enforces state, invoking the
> **Set** operation against it behaves the same way. DSC tests each nested instance and fails the
> operation if any assertion isn't met, without changing the system.

## See also

- [Microsoft.DSC/Assertion resource](../index.md)
- [Gate a configuration with an assertion](./gate-a-configuration-with-an-assertion.md)
- [Microsoft/OSInfo resource][02]

<!-- Link reference definitions -->
[01]: ../../../../../cli/config/test.md
[02]: ../../../../Microsoft/OSInfo/index.md
