# coding: utf-8

if __name__ == "__main__":

    syscalls = set()

    with open("syscalls", "r") as file:
        seccomp_found = False

        for line in file:

            # We don't want to list syscalls before our seccomp filter is effective
            if not seccomp_found:
                if line.startswith("seccomp"):
                    seccomp_found = True

            elif "(" in line:
                syscall = line.split("(")[0]
                syscalls.add(syscall)

    if "seccomp" in syscalls:
        syscalls.remove("seccomp")

    if len(syscalls) == 0:
        print("No syscall detected. Is it a program ??")
        exit(1)

    print("scmp_filter_ctx ctx = seccomp_init(SCMP_ACT_KILL);")

    for syscall in syscalls:
        print(f"seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS({syscall}), 0);")

    print("seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(exit_group), 0);")
    print("seccomp_load(ctx);")
