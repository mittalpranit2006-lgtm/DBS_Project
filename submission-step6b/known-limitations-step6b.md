# Known limitations at Step 6B handoff

1. Cycle VI is still missing or unverified against G1 p.2. Do not claim full lab-cycle coverage.
2. The historical Review 1 diagrams have nine relations. The supplied implementation drawings amend them to eight; faculty approval or an amended submission remains outstanding.
3. G1 pp.1–2 require individual handwritten work and a complete handwritten report with hard-copy SQL outputs. The DOCX/PDF and guides are digital reference drafts only.
4. The local app does not implement genuine rental cancellation, payment refund/reversal, login or application-level authorization. These were not established as explicit G1/G2 requirements. EMPLOYEE.Role is data, not access control.
5. A lost response after a write can leave an uncertain outcome. The UI warns to refresh/search; there are no cross-retry idempotency keys. No automatic retry is performed.
6. The normal committed demonstration retained CUSTOMER 1981, VEHICLE 3981, RENTAL 7016 and PAYMENT 8018 as protected history. Final counts are 11/11/10/10/11/10/11/11; all 81 original seed records are unchanged.
7. Lists are bounded to 100 results without offset pagination. The sample dataset is smaller.

See `docs/known-limitations.md` and `docs/acceptance-test-results.md` for full testing context.
