---
status: accepted
---

# Use soft limits for the private pilot

The unpaid ten-tester pilot allows two registered iPhones per tester, assigns a distinct device identity to each, treats one active device as a monitored policy, and applies a 100 GB calendar-month soft quota. Stock Xray observes counters and can reject future authentication after credential removal, but it cannot atomically reject the newer of two device sessions, provide lossless billing counters, or terminate every authenticated stream exactly at quota or expiry.

The operator must describe those limits honestly: overlap is detected and handled, quota enforcement may lag by up to five minutes, and existing streams may outlive removal until they close. The counters are pilot controls, not a basis for overage billing.
