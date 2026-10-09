# Keep nixos-rebuild from monopolising this laptop.
# Import it from configuration.nix:
#   imports = [ ./hardware-configuration.nix ./terminal.nix ./nix-builds.nix ];

{ ... }:

{
  # This machine has 4 threads and ~5.7 GiB of usable RAM, of which roughly
  # half is already taken by an editor and a browser. The stock settings are
  # max-jobs = "auto" (4 here) and cores = 0 (every thread per build), so up to
  # 4 derivations may each spawn 4 compiler processes: 16 on 4 threads, and 4
  # concurrent link steps can exhaust RAM and trigger the OOM killer.
  #
  # 2 x 2 caps total parallelism at the thread count and bounds peak memory to
  # two derivations at a time. If a rebuild still runs out of memory, switch to
  # max-jobs = 1 with cores = 4: one derivation at a time, still using every
  # thread, which is the most memory-frugal combination.
  nix.settings = {
    max-jobs = 2;
    cores = 2;
  };

  # Build processes inherit the daemon's scheduling, so an expensive rebuild
  # yields to interactive work instead of competing with it. The option
  # documentation recommends exactly this for "desktop or portable computers
  # used interactively". The trade-off is that builds can be starved while the
  # machine is busy, which is the right way round on a laptop.
  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";
  # daemonIOSchedPriority is left at its default on purpose: the idle I/O class
  # ignores priorities entirely.
}
