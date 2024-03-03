#include <stdio.h>

int sum_func (int (*)(int), int, int);

int nested_carrier (int a, int b, int n) {
	int loc_var = n;
	int multiply2 (int z) { return z + z + loc_var; }
	return sum_func (multiply2, a, b);
}

int main (void) {
	return printf ("Fancy calculation (%d)", nested_carrier (5, 4, 8));
}

int sum_func (int (* func)(int), int arg1, int arg2) {
	return func (arg1) + func (arg2);
}
