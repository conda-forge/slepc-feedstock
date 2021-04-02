include ${SLEPC_DIR}/lib/slepc/conf/slepc_common

test10: test10.o chkopts
	${CLINKER} -o test10 test10.o ${SLEPC_LIB}
	${RM} test10.o

test14f: test14f.o chkopts
	${FLINKER} -o test14f test14f.o ${SLEPC_LIB}
	${RM} test14f.o

runtest10: runtest10_krylovschur \
           runtest10_arnoldi \
	   runtest10_lanczos \
           runtest10_gd \
           runtest10_jd \
           runtest10_rqcg \
           runtest10_lobpcg
runtest10_lanczos: epsopts=-eps_lanczos_reorthog local
runtest10_gd:      epsopts=-eps_gd_double_expansion
runtest10_%:
	${MPIEXEC} -n 1 ./test10 -eps_type $* ${epsopts} -eps_nev 4 -m 11 -eps_max_it 500

runtest14f:
	${MPIEXEC} -n 1 ./test14f
