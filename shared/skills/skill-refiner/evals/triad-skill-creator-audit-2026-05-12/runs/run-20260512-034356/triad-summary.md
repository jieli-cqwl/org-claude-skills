# Triad Audit Summary

- baseline: pass_rate=0.8741 wins=3/10
- skill_creator: pass_rate=0.8889 wins=4/10
- skill_refiner: pass_rate=0.8444 wins=5/10

## existing-review-create-request
- winner: baseline
- baseline: 13/13
- skill_creator: 12/13
- skill_refiner: 11/13

## noisy-implementation-skill
- winner: baseline
- baseline: 13/15
- skill_creator: 12/15
- skill_refiner: 8/15

## old-test-preserves-noise
- winner: baseline, skill_refiner
- baseline: 11/15
- skill_creator: 10/15
- skill_refiner: 11/15

## split-monolith-skill
- winner: skill_refiner
- baseline: 12/14
- skill_creator: 12/14
- skill_refiner: 14/14

## simple-trigger-description
- winner: skill_creator
- baseline: 10/12
- skill_creator: 12/12
- skill_refiner: 9/12

## batch-optimize-many-skills
- winner: skill_creator, skill_refiner
- baseline: 11/12
- skill_creator: 12/12
- skill_refiner: 12/12

## unclear-domain-rewrite-request
- winner: skill_refiner
- baseline: 11/13
- skill_creator: 11/13
- skill_refiner: 12/13

## external-practice-depth
- winner: skill_refiner
- baseline: 13/14
- skill_creator: 13/14
- skill_refiner: 14/14

## completion-proof-claim
- winner: skill_creator
- baseline: 11/13
- skill_creator: 12/13
- skill_refiner: 11/13

## new-skill-from-scratch
- winner: skill_creator
- baseline: 13/14
- skill_creator: 14/14
- skill_refiner: 12/14
