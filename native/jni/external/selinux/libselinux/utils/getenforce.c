#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <selinux/selinux.h>

int main(int argc __attribute__ ((unused)),
	 char **argv __attribute__ ((unused)))
{
	int rc;

	rc = is_selinux_enabled();
	if (rc < 0) {
		fputs("getenforce:  is_selinux_enabled() failed", stderr);
		return 2;
	}
	if (rc == 1) {
		rc = security_getenforce();
		if (rc < 0) {
			fputs("getenforce:  getenforce() failed", stderr);
			return 2;
		}

		if (rc)
			puts("Enforcing");
		else
			puts("Permissive");
	} else {
		puts("Disabled");
	}

	return 0;
}
