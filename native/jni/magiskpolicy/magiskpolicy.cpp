#include <utils.hpp>
#include <magiskpolicy.hpp>

#include "sepolicy.hpp"

using namespace std::literals;

[[noreturn]] static void usage(char *arg0) {
    fprintf(stderr,
R"EOF(MagiskPolicy - Sepolicy Patch Tool

Usage: %s [--options...] [policy statements...]

Options:
   --help            show help message for policy statements
   --load FILE       load policies from FILE
   --load-split      load from precompiled sepolicy or compile
                     split policies
   --compile-split   compile split cil policies
   --save FILE       save policies to FILE
   --live            directly apply sepolicy live
   --magisk          inject built-in rules for a minimal
                     Magisk selinux environment
   --apply FILE      apply rules from FILE, read and parsed
                     line by line as policy statements

If neither --load or --compile-split is specified, it will load
from current live policies (/sys/fs/selinux/policy)

)EOF", arg0);
    exit(1);
}

int magiskpolicy_main(int argc, char *argv[]) {
    cmdline_logging();
    const char *out_file = nullptr;
    const char *rule_file = nullptr;
    sepolicy *sepol = nullptr;
    bool magisk = false;
    bool live = false;

    if (argc < 2) usage(argv[0]);
    int i = 1;
    for (; i < argc; ++i) {
        // Parse options
        if (argv[i][0] == '-' && argv[i][1] == '-') {
            auto option = argv[i] + 2;
            if (option == "live"sv)
                live = true;
            else if (option == "magisk"sv)
                magisk = true;
            else if (option == "load"sv) {
                if (argv[i + 1] == nullptr)
                    usage(argv[0]);
                sepol = sepolicy::from_file(argv[i + 1]);
                if (!sepol) {
                    fprintf(stderr, "Cannot load policy from %s\n", argv[i + 1]);
                    return 1;
                }
                ++i;
            } else if (option == "load-split"sv) {
                sepol = sepolicy::from_split();
                if (!sepol) {
                    fprintf(stderr, "Cannot load split cil\n");
                    return 1;
                }
            } else if (option == "compile-split"sv) {
                sepol = sepolicy::compile_split();
                if (!sepol) {
                    fprintf(stderr, "Cannot compile split cil\n");
                    return 1;
                }
            } else if (option == "save"sv) {
                if (argv[i + 1] == nullptr)
                    usage(argv[0]);
                out_file = argv[i + 1];
                ++i;
            } else if (option == "apply"sv) {
                if (argv[i + 1] == nullptr)
                    usage(argv[0]);
                rule_file = argv[i + 1];
                ++i;
            } else if (option == "help"sv) {
                statement_help();
            } else {
                usage(argv[0]);
            }
        } else {
            break;
        }
    }

    // Use current policy if nothing is loaded
    if (sepol == nullptr && !(sepol = sepolicy::from_file(SELINUX_POLICY))) {
        fprintf(stderr, "Cannot load policy from " SELINUX_POLICY "\n");
        return 1;
    }

    if (magisk)
        sepol->magisk_rules();

    if (rule_file)
        sepol->load_rule_file(rule_file);

    for (; i < argc; ++i)
        sepol->parse_statement(argv[i]);

    if (live && !sepol->to_file(SELINUX_LOAD)) {
        fprintf(stderr, "Cannot apply policy\n");
        return 1;
    }

    if (out_file && !sepol->to_file(out_file)) {
        fprintf(stderr, "Cannot dump policy to %s\n", out_file);
        return 1;
    }

    delete sepol;
    return 0;
}
