import { LightningElement, api, wire } from "lwc";
import getSummary from "@salesforce/apex/Unit360Controller.getSummary";

const recordUrl = (id) => `/lightning/r/${id}/view`;

export default class Unit360 extends LightningElement {
  @api recordId;

  summary;
  error;

  // Cacheable Apex through @wire: re-runs automatically when recordId changes.
  @wire(getSummary, { recordId: "$recordId" })
  wiredSummary({ data, error }) {
    if (data) {
      this.summary = data;
      this.error = undefined;
    } else if (error) {
      this.error = error;
      this.summary = undefined;
    }
  }

  get isLoading() {
    return !this.summary && !this.error;
  }

  get isUnitPage() {
    return this.summary?.context === "Unit";
  }

  get occupantsTitle() {
    return this.isUnitPage ? "Current occupants" : "Current units";
  }

  get occupants() {
    return (this.summary?.occupants ?? []).map((o) => ({
      ...o,
      url: recordUrl(o.recordId)
    }));
  }

  get hasOccupants() {
    return this.occupants.length > 0;
  }

  get cases() {
    return (this.summary?.recentCases ?? []).map((c) => ({
      ...c,
      url: recordUrl(c.id),
      statusClass:
        c.status === "Closed" ? "slds-badge" : "slds-badge slds-theme_info",
      flag: c.slaBreached ? "SLA breached" : c.escalated ? "Escalated" : null
    }));
  }

  get hasCases() {
    return this.cases.length > 0;
  }

  get openCases() {
    return this.summary?.openCases ?? 0;
  }

  get avgResolution() {
    const hours = this.summary?.avgResolutionHours;
    return hours === null || hours === undefined ? "No data yet" : `${hours} h`;
  }

  get avgRating() {
    const rating = this.summary?.avgRating;
    return rating === null || rating === undefined
      ? "No ratings yet"
      : `${rating} / 5`;
  }

  get errorMessage() {
    const body = this.error?.body;
    if (Array.isArray(body)) {
      return body.map((e) => e.message).join(", ");
    }
    return body?.message ?? "Unit 360 could not be loaded.";
  }
}
