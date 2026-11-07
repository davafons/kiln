import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"
import { application } from "controllers/application"

lazyLoadControllersFrom("controllers", application)
