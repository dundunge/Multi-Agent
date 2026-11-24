import type { SVGProps } from "react";

export function T3Wordmark(props: SVGProps<SVGSVGElement>) {
  return (
    <svg {...props} viewBox="0 0 128 128" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path
        d="M46 38Q50.5 59.5 67.5 64Q50.5 68.5 46 90Q41.5 68.5 24.5 64Q41.5 59.5 46 38Z"
        fill="currentColor"
      />
      <path
        d="M65 44A26 26 0 0 1 65 84M79 34A40 40 0 0 1 79 94"
        stroke="currentColor"
        strokeWidth="6.5"
        strokeLinecap="round"
        opacity="0.88"
      />
      <circle cx="95" cy="34" r="6.5" fill="currentColor" />
      <circle cx="104" cy="64" r="7.5" fill="currentColor" />
      <circle cx="95" cy="94" r="6.5" fill="currentColor" />
    </svg>
  );
}
