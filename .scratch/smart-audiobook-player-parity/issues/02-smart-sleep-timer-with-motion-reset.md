# 02: Smart Sleep Timer with Motion Detection Reset

**What to build:**
A dedicated `SmartSleepTimerService` supporting traditional countdown duration/end-of-chapter timers, integrated with accelerometer motion detection (`sensors_plus`) during the final 2-minute grace period to automatically extend the timer upon shaking/moving the phone.

**Blocked by:** 01-per-book-state-and-short-rewind

**Status:** ready-for-agent

- [ ] Sleep timer countdown logic with pause trigger upon expiration
- [ ] Motion detection listening enabled exclusively in the last 2 minutes of countdown
- [ ] Accelerometer shake event resets countdown timer to initial or configured extension duration
- [ ] Sensitivity threshold setting (Low, Medium, High)
- [ ] Unit & service tests verifying timer expiration and motion reset behavior
