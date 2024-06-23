// 1. Import the extendTheme function
import {
  extendTheme,
  StyleFunctionProps,
  type ThemeConfig,
} from "@chakra-ui/react";
import { mode } from "@chakra-ui/theme-tools";
// 2. Extend the theme to include custom colors, fonts, etc
const colors = {
 
};

// 2. Add your color mode config
// const config: ThemeConfig = {
//   initialColorMode: "light",
//   useSystemColorMode: false,
// };

const config: ThemeConfig = {
  initialColorMode: "dark",
  useSystemColorMode: true,
};

const theme = extendTheme({
  colors,
  config,
  styles: {
    global: (props: StyleFunctionProps) => ({
      body: {
        color: mode("gray.700", "gray.200")(props),
        bg: mode("gray.200", "gray.800")(props),
        lineHeight: "base",
      },
    }),
  },
  components: {
    Text: {
      sizes: {
        sm: {
          fontSize: "17px",
          px: 4, // <-- px is short for paddingLeft and paddingRight
          py: 3, // <-- py is short for paddingTop and paddingBottom
        },
        md: {
          fontSize: "21px",
          px: 6, // <-- these values are tokens from the design system
          py: 4, // <-- these values are tokens from the design system
        },
        lg: {
          fontSize: "25px",
          px: 6, // <-- these values are tokens from the design system
          py: 4, // <-- these values are tokens from the design system
        },
      },
  
    },
  },
});

export default theme;
