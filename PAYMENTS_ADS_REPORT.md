# Backend Payments and Ads System Issue Report

This report outlines every problem identified in the backend folders and files related to ads and payments.

## 1. File: `backend/app/api/v1/endpoints/billing_webhook.py`
* **Issue:** Missing specific exception handling in UUID parsing.
* **Line Code:** ~55
* **Details:** The function `process_revenuecat_event` parsed `uuid.UUID()` using `except ValueError:`. The `uuid.UUID` function can also throw a `TypeError` if a non-string/non-bytes object is passed, which would crash the endpoint with an HTTP 500 error instead of a graceful ignored status.
* **Resolution:** Replaced `except ValueError:` with `except (ValueError, TypeError):`.

## 2. File: `backend/app/api/v1/endpoints/ads_ssv.py`
* **Issue 1:** Swallowed Base64 decoding exception.
* **Line Code:** ~84
* **Details:** The signature decoding caught a very broad `Exception` when handling `base64.urlsafe_b64decode`. This could mask completely unrelated errors like syntax errors.
* **Resolution:** Updated to specifically catch `(ValueError, TypeError)`.

* **Issue 2:** Missing specific exception handling in UUID parsing.
* **Line Code:** ~194
* **Details:** The endpoint parsed user UUID with `except ValueError:`, risking a 500 error if `TypeError` was raised.
* **Resolution:** Replaced `except ValueError:` with `except (ValueError, TypeError):`.

## 3. File: `backend/app/api/v1/endpoints/web_store.py`
* **Issue 1:** Swallowed Order Persistence Errors.
* **Line Code:** ~222 and ~306
* **Details:** In `create_store_order` and `complete_store_order`, database commit operations were wrapped in a broad `except Exception as e:` block. This resulted in the application printing warnings or just swallowing the error and continuing as if the order succeeded, leaving the system in an inconsistent state and returning a 200 OK.
* **Resolution:** Changed to catch `SQLAlchemyError` specifically, and added `raise HTTPException(status_code=500, detail="Failed to persist order to database.")` to explicitly fail and notify the client on database failure.

* **Issue 2:** Broad Exception catching in UUID parsing.
* **Line Code:** ~124, ~194, and ~363
* **Details:** When parsing the search query into a UUID to find a user, it caught `Exception` which is considered a bad practice as it could swallow other unintentional errors.
* **Resolution:** Changed `except Exception:` to `except (ValueError, TypeError):` in user UUID lookup logic.

## 4. Tests dependencies issue (`backend/requirements.txt` / Pip dependencies)
* **Issue:** Local or pipeline tests failures due to missing testing HTTP client `httpx` and module imports.
* **Details:** When running test commands for `test_ads_and_admin.py`, `test_phase5_monetization.py`, and `test_chunk2_financial_hardening.py`, the system threw `ModuleNotFoundError` for `httpx`. These issues were resolved by manually installing required packages and adjusting environment paths in earlier steps, which should be verified continuously during pipeline builds.
