/**
 * Tests for the KYC review queue page.
 *
 * These cover:
 *   - renders the loading state on first paint
 *   - fetches /admin/kyc/pending on mount and shows pending rows
 *   - filters out non-pending drivers the backend accidentally returns
 *   - Approve button removes the row and posts to /admin/drivers/{id}/approve
 *   - Reject opens the modal, requires a non-empty reason, then posts the note
 *   - Server failure on Approve reverts the optimistic row removal
 *   - Empty state appears when no drivers are pending
 */

import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { cleanup, fireEvent, render, screen, waitFor, within } from "@testing-library/react"
import { MemoryRouter } from "react-router-dom"
import { LocaleProvider } from "../i18n/LocaleProvider"
import { KycQueuePage } from "./KycQueuePage"
import type { Driver } from "../api/client"

vi.mock("../api/client", () => ({
  api: vi.fn(),
}))

import { api } from "../api/client";

const mockApi = api as unknown as ReturnType<typeof vi.fn>;

function makeDriver(over: Partial<Driver> = {}): Driver {
  return {
    id: "d1",
    name: "Karim Mia",
    phone: "+8801711000001",
    plate: "DHAKA METRO-GA 11-1111",
    kyc: "pending",
    online: false,
    lat: 23.79,
    lng: 90.41,
    nid: "199012345678",
    rating: 4.8,
    ...over,
  };
}

function renderPage() {
  return render(
    <MemoryRouter>
      <LocaleProvider>
        <KycQueuePage />
      </LocaleProvider>
    </MemoryRouter>,
  );
}

describe("KycQueuePage", () => {
  beforeEach(() => {
    mockApi.mockReset();
  });

  afterEach(() => {
    cleanup();
    vi.clearAllMocks();
  });

  function rowFor(name: string): HTMLElement {
    // Scope queries to the table row that contains the driver name so
    // that helpers (Approve / Reject) never resolve to another row.
    const cell = screen.getByText(name);
    const row = cell.closest("tr");
    if (!row) throw new Error(`No row for ${name}`);
    return row as HTMLElement;
  }

  it("renders the loading state on first paint", () => {
    mockApi.mockResolvedValueOnce([]);
    renderPage();
    expect(screen.getByText(/লোড হচ্ছে|Loading/i)).toBeTruthy();
  });

  it("fetches /admin/kyc/pending on mount and shows pending rows", async () => {
    const drivers = [
      makeDriver({ id: "d1", name: "Karim Mia" }),
      makeDriver({ id: "d2", name: "Rahim Uddin", phone: "+8801711222333" }),
    ];
    mockApi.mockResolvedValueOnce(drivers);

    renderPage();

    await waitFor(() => {
      expect(screen.getByText("Karim Mia")).toBeTruthy();
      expect(screen.getByText("Rahim Uddin")).toBeTruthy();
    });
    expect(mockApi).toHaveBeenCalledWith("/admin/kyc/pending");
  });

  it("filters out non-pending drivers the backend accidentally returns", async () => {
    mockApi.mockResolvedValueOnce([
      makeDriver({ id: "d1", name: "Should Show" }),
      makeDriver({ id: "d2", name: "Already Verified", kyc: "verified" }),
      makeDriver({ id: "d3", name: "Already Rejected", kyc: "rejected" }),
    ]);

    renderPage();

    await waitFor(() => {
      expect(screen.getByText("Should Show")).toBeTruthy();
    });
    expect(screen.queryByText("Already Verified")).toBeNull();
    expect(screen.queryByText("Already Rejected")).toBeNull();
  });

  it("shows the empty state when there are no pending drivers", async () => {
    mockApi.mockResolvedValueOnce([]);
    renderPage();
    await waitFor(() => {
      // Bengali empty message
      expect(screen.getByText(/KYC যাচাইয়ের জন্য অপেক্ষা/i)).toBeTruthy();
    });
  });

  it("Approve removes the row optimistically and POSTs to /admin/drivers/{id}/approve", async () => {
    const driver = makeDriver({ id: "d1", name: "Approved One" });
    mockApi
      .mockResolvedValueOnce([driver])
      .mockResolvedValueOnce({ data: null });

    renderPage();

    await waitFor(() => screen.getByText("Approved One"));

    const row = rowFor("Approved One");
    const approveButton = within(row).getByRole("button", {
      name: /অ্যাপ্রুভ|Approve/i,
    });
    fireEvent.click(approveButton);

    await waitFor(() => {
      expect(screen.queryByText("Approved One")).toBeNull();
    });
    expect(mockApi).toHaveBeenCalledWith("/admin/drivers/d1/approve", {
      method: "POST",
    });
  });

  it("Approve failure reverts the row and shows an error", async () => {
    const driver = makeDriver({ id: "d1", name: "Will Revert" });
    mockApi
      .mockResolvedValueOnce([driver])
      .mockRejectedValueOnce(new Error("server down"));

    renderPage();

    await waitFor(() => screen.getByText("Will Revert"));
    const row = rowFor("Will Revert");
    fireEvent.click(
      within(row).getByRole("button", { name: /অ্যাপ্রুভ|Approve/i }),
    );

    await waitFor(() => {
      expect(screen.getByText("Will Revert")).toBeTruthy();
      expect(screen.getByText("server down")).toBeTruthy();
    });
  });

  it("Reject modal requires a reason and POSTs it as the body", async () => {
    const driver = makeDriver({ id: "d1", name: "Will Reject" });
    mockApi
      .mockResolvedValueOnce([driver])
      .mockResolvedValueOnce({ data: null });

    renderPage();

    await waitFor(() => screen.getByText("Will Reject"));
    const row = rowFor("Will Reject");
    fireEvent.click(
      within(row).getByRole("button", { name: /রিজেক্ট|Reject/i }),
    );

    // Modal is open. Confirm button should be disabled until we type a reason.
    const confirmButton = screen.getByRole("button", {
      name: /প্রত্যাখ্যান নিশ্চিত|Confirm reject/i,
    });
    expect(confirmButton.hasAttribute("disabled")).toBe(true);

    const textarea = screen.getByLabelText(/প্রত্যাখ্যানের কারণ|Rejection reason/i);
    fireEvent.change(textarea, { target: { value: "Photo is blurry" } });

    await waitFor(() => expect(confirmButton.hasAttribute("disabled")).toBe(false));
    fireEvent.click(confirmButton);

    await waitFor(() => {
      expect(screen.queryByText("Will Reject")).toBeNull();
    });
    expect(mockApi).toHaveBeenCalledWith("/admin/drivers/d1/reject", {
      method: "POST",
      json: { note: "Photo is blurry" },
    });
  });

  it("Reject modal Cancel button closes without calling the API", async () => {
    const driver = makeDriver({ id: "d1" });
    mockApi.mockResolvedValueOnce([driver]);

    renderPage();
    await waitFor(() => screen.getByText("Karim Mia"));
    const row = rowFor("Karim Mia");
    fireEvent.click(
      within(row).getByRole("button", { name: /রিজেক্ট|Reject/i }),
    );

    fireEvent.click(screen.getByRole("button", { name: /বাতিল|Cancel/i }));

    await waitFor(() => {
      expect(screen.queryByLabelText(/প্রত্যাখ্যানের কারণ/i)).toBeNull();
    });
    expect(mockApi).toHaveBeenCalledTimes(1); // only the initial GET
  });
});
