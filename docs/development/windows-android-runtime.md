# Windows Android runtime preparation

Issue [#184](https://github.com/vypdev/zstandard/issues/184) adds Windows-hosted
Android execution separately from the passing source-resolution/NDK regression.
Linux retains its full execution matrix. No release or publication belongs to
this work.

## Observed host and current evidence

The [read-only diagnostic run](https://github.com/vypdev/zstandard/actions/runs/41029979627)
on 2026-10-30 reported:

| Observation | Result |
| --- | --- |
| Runner | `windows-ryzen-runner-3`, session 0 |
| Native architecture (`IsWow64Process2`) | AMD64, `0x8664` |
| Windows | Windows 11 Pro, build 26300 |
| Machine | Microsoft Hyper-V virtual machine |
| Processor | AMD Ryzen 5 7430U; 6 logical processors exposed |
| Guest memory | About 6.7 GiB total; about 1.8 GiB physically available |
| Available commit headroom | About 1.6 GiB at diagnosis time |
| Windows Hypervisor Platform | Disabled (`InstallState=2`) |
| Guest CPU capability queries | SLAT and VM-monitor extensions reported false |

The earlier emulator reported unavailable virtualization extensions with
`emulator -accel-check` exit 3. The new host report confirms the feature state;
it does not prove the outer VM's current `ExposeVirtualizationExtensions` value.
The operator must inspect that value on the physical Hyper-V host. Guest WMI
flags alone are insufficient to determine the complete nested configuration.

The application event log also contains `crashpad_handler.exe` exception
`0x80000003` from the first experiment's private SDK. This identifies an owned
crash-reporter failure, **not the emulator engine's exit code or the proven
cause of either guest boot failure**. The earlier launcher did not retain the
engine exit code. No compression test ran in either failed experiment.

Windows Android tooling distinguishes graphics rendering from CPU acceleration.
Google recommends WHPX for Windows; `swiftshader_indirect` was deprecated in
emulator 36.4.9. A modern software renderer is a separate test variable and does
not supply missing CPU virtualization or memory.

## Operator review before host changes

Repository jobs do not enable Windows features, reconfigure the outer VM,
reboot shared hosts, disable security protections, or terminate other jobs.
Choose a supported physical Windows x64 runner, or review a nested Hyper-V
configuration with the operator. An unsupported software-only route must first
demonstrate actual stable boot and execution; it cannot be reported as tested
runtime coverage.

For the existing VM, the proposed preparation is:

1. Identify the VM hosting `windows-ryzen-runner-*`. Confirm the physical host's
   Windows/Hyper-V version and AMD nested-virtualization support. Capture its
   current processor, memory and feature settings before changing anything.
2. Drain its runner services and agree a maintenance window. Do not stop a busy
   VM or discard other users' work from a repository workflow.
3. On the physical host, with the VM shut down, expose virtualization extensions.
   Provision enough memory for Windows, the SDK/JVM, Flutter and one guest at
   the same time. Start with 12 GiB guest RAM if host capacity allows; 16 GiB is
   preferable for a shared build VM. These are project operating targets, not
   claims that a memory setting alone fixes the boot failure.
4. In the guest, enable Windows Hypervisor Platform during the approved window
   and reboot. Preserve existing Hyper-V/VBS/security settings.
5. Start the runner services and repeat the read-only diagnostic. Confirm the
   actual emulator's `-accel-check` reports a usable WHPX accelerator before
   running the runtime job. If the current VM cannot provide this, select a
   compatible host and confirm its runner labels.

### Commands for the operator to review

These are a plan, **not commands executed by CI**. Substitute the actual VM name
after identifying it on the Hyper-V host.

```powershell
$androidVmName = '<actual VM name>'
Get-VM -Name $androidVmName | Select-Object Name, State, Version
Get-VMProcessor -VMName $androidVmName |
    Select-Object Count, ExposeVirtualizationExtensions
Get-VMMemory -VMName $androidVmName |
    Select-Object DynamicMemoryEnabled, Startup, Minimum, Maximum
```

After draining jobs and shutting down that VM, the reviewed host change is:

```powershell
if ((Get-VM -Name $androidVmName).State -ne 'Off') {
    throw 'Drain jobs and shut down the selected VM before this change.'
}
Set-VMProcessor -VMName $androidVmName -ExposeVirtualizationExtensions $true
# Select a memory budget the physical host can actually sustain.
$androidVmMemory = 12GB
Set-VMMemory -VMName $androidVmName -DynamicMemoryEnabled $false -StartupBytes $androidVmMemory
```

Inside the guest, after operator approval:

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -All -NoRestart
# Reboot only in the agreed maintenance window, then restart the runner services.
```

Rollback is also an operator operation: restore the recorded VM processor and
memory values with the VM shut down, and review restoration of the guest's
previous feature state and required reboot. Repository code does not perform an
automatic rollback or change runner registration, Copilot or published tags.

## Required runtime validation

Successful host inspection is only capability evidence. Before declaring this
issue complete, one targeted job must use the repository's pinned Flutter SDK
and a private SDK/AVD/Gradle/Flutter settings profile, stage both candidate
packages outside the checkout, and execute:

- The existing Flutter compression integration suite.
- The 100 deterministic compression/decompression property cases.
- The existing JNI instrumentation checks.

Require three consecutive clean-job successes covering boot, tests and owned
resource cleanup. Missing prerequisites and failed boots must fail explicitly.
Bound downloads, boot, ADB and test commands. Serialize shared-host emulator
sessions, use unused ports/private ADB, retain bounded failure diagnostics and
stop only processes owned by that job, including after cancellation. Keep the
existing Linux runtime matrix and Windows source/build regression unchanged.

## Primary references

- [Android graphics and VM acceleration](https://developer.android.com/studio/run/emulator-acceleration)
- [Android emulator troubleshooting: memory and commit charge](https://developer.android.com/studio/run/emulator-troubleshooting)
- [Microsoft native process/OS architecture API](https://learn.microsoft.com/en-us/windows/win32/api/wow64apiset/nf-wow64apiset-iswow64process2)
- [Microsoft optional-feature state definitions](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-optionalfeature)
- [Microsoft nested Hyper-V overview](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/nested-virtualization)
