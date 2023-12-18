#include <stdio.h>
#include <immintrin.h>
int main() {
    int a[8] = {0, 2, 4, 6, 8, 10, 12, 14};
    int b[8] = {1, 1, 1, 1, 1,  1,  1,  1};
    int c[8] = {0, 2, 4, 7, 8, 10, 12, 14};
    int d[8];
    printf("Trying MAJ3:\n");
    __m256i a8 = _mm256_loadu_si256((__m256i*)a);
    __m256i b8 = _mm256_loadu_si256((__m256i*)b);
    __m256i c8 = _mm256_loadu_si256((__m256i*)c);

    __m256i d8 = _mm256_castps_si256(  _mm256_or_ps( _mm256_or_ps( _mm256_and_ps( _mm256_castsi256_ps(a8), _mm256_castsi256_ps(b8)) ,  _mm256_and_ps( _mm256_castsi256_ps(b8), _mm256_castsi256_ps(c8))), _mm256_and_ps( _mm256_castsi256_ps(a8), _mm256_castsi256_ps(c8))  ));

    _mm256_storeu_si256((__m256i*)d, d8);
    for(int i=0; i<8; i++) printf("%d ", c[i]); printf("\n");
    //output: 0 2 4 7 8 10 12 14
}

