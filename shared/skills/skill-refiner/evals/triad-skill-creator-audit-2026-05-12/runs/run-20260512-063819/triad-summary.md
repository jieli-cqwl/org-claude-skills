# Triad Audit Summary

- baseline: pass_rate=1.0 wins=15/15
- skill_creator: pass_rate=0.9426 wins=6/15
- skill_refiner: pass_rate=0.9856 wins=12/15

## existing-review-create-request
- winner: baseline, skill_creator, skill_refiner
- baseline: 13/13
- skill_creator: 13/13
- skill_refiner: 13/13

## noisy-implementation-skill
- winner: baseline, skill_refiner
- baseline: 15/15
- skill_creator: 14/15
- skill_refiner: 15/15

## old-test-preserves-noise
- winner: baseline, skill_refiner
- baseline: 15/15
- skill_creator: 13/15
- skill_refiner: 15/15

## split-monolith-skill
- winner: baseline, skill_refiner
- baseline: 14/14
- skill_creator: 13/14
- skill_refiner: 14/14

## simple-trigger-description
- winner: baseline, skill_creator, skill_refiner
- baseline: 12/12
- skill_creator: 12/12
- skill_refiner: 12/12

## batch-optimize-many-skills
- winner: baseline, skill_refiner
- baseline: 12/12
- skill_creator: 11/12
- skill_refiner: 12/12

## unclear-domain-rewrite-request
- winner: baseline
- baseline: 13/13
- skill_creator: 10/13
- skill_refiner: 12/13

## external-practice-depth
- winner: baseline, skill_refiner
- baseline: 14/14
- skill_creator: 13/14
- skill_refiner: 14/14

## completion-proof-claim
- winner: baseline, skill_creator, skill_refiner
- baseline: 13/13
- skill_creator: 13/13
- skill_refiner: 13/13

## new-skill-from-scratch
- winner: baseline, skill_creator
- baseline: 14/14
- skill_creator: 14/14
- skill_refiner: 13/14

## self-retain-upgrade-pressure
- winner: baseline, skill_creator
- baseline: 15/15
- skill_creator: 15/15
- skill_refiner: 14/15

## failing-eval-pressure
- winner: baseline, skill_creator, skill_refiner
- baseline: 15/15
- skill_creator: 15/15
- skill_refiner: 15/15

## user-provides-solution-not-problem
- winner: baseline, skill_refiner
- baseline: 15/15
- skill_creator: 14/15
- skill_refiner: 15/15

## conflicting-adjacent-skills
- winner: baseline, skill_refiner
- baseline: 15/15
- skill_creator: 14/15
- skill_refiner: 15/15

## historical-artifact-residue
- winner: baseline, skill_refiner
- baseline: 14/14
- skill_creator: 13/14
- skill_refiner: 14/14
