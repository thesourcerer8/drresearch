//compiled and ran on an Ivy Bridge system with AVX but without AVX2
#include <stdio.h>
#include <immintrin.h>
int main() {
    int a[8] = {0, 2, 4, 6, 8, 10, 12, 14};
    int b[8] = {1, 1, 1, 1, 1,  1,  1,  1};
    int c[8];
    printf("Trying simple binary OR:\n");
    __m256i a8 = _mm256_loadu_si256((__m256i*)a);
    __m256i b8 = _mm256_loadu_si256((__m256i*)b);
    __m256i c8 = _mm256_castps_si256(
        _mm256_or_ps(_mm256_castsi256_ps(a8), _mm256_castsi256_ps(b8)));
    _mm256_storeu_si256((__m256i*)c, c8);
    for(int i=0; i<8; i++) printf("%d ", c[i]); printf("\n");
    //output: 1 3 5 7 9 11 13 15
}

