/**
 * The only trigger on Case. Kept thin on purpose: all logic lives in CaseTriggerHandler.
 */
trigger CaseTrigger on Case(before insert) {
  new CaseTriggerHandler().run();
}
