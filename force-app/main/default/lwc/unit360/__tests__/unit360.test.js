import { createElement } from "lwc";
import Unit360 from "c/unit360";
import getSummary from "@salesforce/apex/Unit360Controller.getSummary";

jest.mock(
  "@salesforce/apex/Unit360Controller.getSummary",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

const SUMMARY = {
  context: "Unit",
  openCases: 1,
  avgResolutionHours: 6.5,
  avgRating: 4.5,
  occupants: [
    {
      id: "a01000000000001",
      recordId: "003000000000001",
      name: "Asha Rao",
      role: "Owner",
      startDate: "2023-04-01"
    }
  ],
  recentCases: [
    {
      id: "500000000000001",
      caseNumber: "00001001",
      subject: "Leaking tap",
      status: "New",
      escalated: true,
      slaBreached: true
    },
    {
      id: "500000000000002",
      caseNumber: "00001002",
      subject: "Lift stuck",
      status: "Closed",
      escalated: false,
      slaBreached: false
    }
  ]
};

const EMPTY = {
  context: "Unit",
  openCases: 0,
  avgResolutionHours: null,
  avgRating: null,
  occupants: [],
  recentCases: []
};

const flushPromises = () => Promise.resolve();
const byId = (element, id) =>
  element.shadowRoot.querySelector(`[data-id="${id}"]`);

function mount() {
  const element = createElement("c-unit360", { is: Unit360 });
  element.recordId = "a02000000000001";
  document.body.appendChild(element);
  return element;
}

describe("c-unit360", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("shows a spinner until data arrives", () => {
    const element = mount();
    expect(byId(element, "loading")).not.toBeNull();
  });

  it("renders stats, occupants and recent cases", async () => {
    const element = mount();
    getSummary.emit(SUMMARY);
    await flushPromises();

    expect(byId(element, "loading")).toBeNull();
    expect(byId(element, "open-cases").textContent).toBe("1");
    expect(byId(element, "avg-resolution").textContent).toBe("6.5 h");
    expect(byId(element, "avg-rating").textContent).toBe("4.5 / 5");

    const occupantLinks = byId(element, "occupants").querySelectorAll("a");
    expect(occupantLinks).toHaveLength(1);
    expect(occupantLinks[0].textContent).toBe("Asha Rao");
    expect(occupantLinks[0].getAttribute("href")).toBe(
      "/lightning/r/003000000000001/view"
    );

    const caseItems = byId(element, "cases").querySelectorAll("li");
    expect(caseItems).toHaveLength(2);
    expect(caseItems[0].textContent).toContain("00001001");
    expect(caseItems[0].textContent).toContain("SLA breached");
    expect(caseItems[1].textContent).not.toContain("SLA breached");
  });

  it("asks for the record id it is placed on", async () => {
    mount();
    await flushPromises();
    expect(getSummary.getLastConfig()).toEqual({ recordId: "a02000000000001" });
  });

  it("shows empty states when there is nothing to show", async () => {
    const element = mount();
    getSummary.emit(EMPTY);
    await flushPromises();

    expect(byId(element, "no-occupants")).not.toBeNull();
    expect(byId(element, "no-cases")).not.toBeNull();
    expect(byId(element, "avg-resolution").textContent).toBe("No data yet");
    expect(byId(element, "avg-rating").textContent).toBe("No ratings yet");
  });

  it("labels the list as units on a Contact page", async () => {
    const element = mount();
    getSummary.emit({ ...SUMMARY, context: "Contact" });
    await flushPromises();

    const headings = [...element.shadowRoot.querySelectorAll("h3")].map(
      (h) => h.textContent
    );
    expect(headings).toContain("Current units");
  });

  it("shows the server error message", async () => {
    const element = mount();
    getSummary.error({
      message: "You do not have access to some of this information"
    });
    await flushPromises();

    expect(byId(element, "loading")).toBeNull();
    expect(byId(element, "error").textContent).toContain(
      "You do not have access"
    );
  });
});
